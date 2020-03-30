"""
Module: DD (Decision Diagram)
"""

export FullyReduced, QuasiReduced
export defvar!, defval!
export ddval!, ddvar!

using Printf

import Base #: size, length, show, +, -, *, /, adjoint, convert, getindex, iterate

abstract type AbstractDDNode{Tv,Ti} end
abstract type AbstractDDOperator end
abstract type AbstractUnaryDDOperator <: AbstractDDOperator end
abstract type AbstractBinaryDDOperator <: AbstractDDOperator end
# abstract type AbstractTrinaryDDOperator <: AbstractDDOperator end
abstract type AbstractDDPolicy end

"""
AbstractDDForest{Tv,Ti,Tl}

A forest for DD nodes. The parameter Tv represents a type of value. For example, in the case of BDD,
Tv usually becomes Bool. Ti represents a type of value of variable that is defined
in a domain of variable. Tl is a type of level of variables.
The forest takes the following fields.
- vals::Dict{Tv,DDValue} A dictionary for defined values
- vars::Dict{Symbol,Tuple{Tl,DDDomain}} A dictionary for defined variables
- varcache: A cache to ensure the node identification in the forest.
- opcache: A cache for the results
- policy::AbstractDDPolicy An instance of singlton to reduce the nodes.

reference implement:

struct DDForest{Tv,Ti,Tl} <: AbstractDDForest{Tv,Ti,Tl}
    vals::Dict{Tv,DDValue{Tv,Ti}}
    vars::Dict{Symbol,Tuple{Tl,DDDomain{Ti}}}
    varcache::Dict{DDKey{Tv,Ti},AbstractDDNode{Tv,Ti}}
    opcache::Dict{DDOPKey{Tv,Ti},AbstractDDNode{Tv,Ti}}
    policy::AbstractDDPolicy

    function DDForest{Tv,Ti,Tl}(policy) where {Tv,Ti,Tl}
        vals = Dict{Tv,DDValue{Tv,Ti}}()
        vars = Dict{Symbol,Tuple{Tl,DDDomain{Ti}}}()
        varcache = Dict{DDKey{Tv,Ti},DDVariable{Tv,Ti}}()
        opcache = Dict{DDOPKey{Tv,Ti},AbstractDDNode{Tv,Ti}}()
        new(vals, vars, varcache, opcache, policy)
    end
end
"""

abstract type AbstractDDForest{Tv,Ti,Tl} end

"""
DDValue{Tv,Ti} <: AbstractDDNode{Tv,Ti}

This is a structure to express a value in DD (a bottom node in DD).
The parameter Tv represents a type of value. For example, in the case of BDD,
Tv usually becomes Bool. Ti represents a type of value of variable that is defined
in a domain of variable.
"""

struct DDValue{Tv,Ti} <: AbstractDDNode{Tv,Ti}
    val::Tv
end

"""
DDVariable{Tv,Ti,N} <: AbstractDDNode{Tv,Ti}

This is a structure to express a variable in DD.
The parameter Tv represents a type of value. For example, in the case of BDD,
Tv usually becomes Bool. Ti represents a type of value of variable that is defined
in a domain of variable.
"""

struct DDVariable{Tv,Ti,N} <: AbstractDDNode{Tv,Ti}
    label::Symbol
    nodes::NTuple{N,AbstractDDNode{Tv,Ti}}

    function DDVariable{Tv,Ti,N}(label::Symbol,
            nodes::Vararg{AbstractDDNode{Tv,Ti},N}) where {Tv,Ti,N}
        new(label, nodes)
    end
end

"""
type alias
"""

const DDVariable{Tv,Ti} = DDVariable{Tv,Ti,N} where N
const DDKey{Tv,Ti} = Tuple{Symbol,NTuple{N,AbstractDDNode{Tv,Ti}}} where N
const DDOPKey{Tv,Ti} = Tuple{AbstractDDOperator,NTuple{N,AbstractDDNode{Tv,Ti}}} where N

"""
FullyReduced <: AbstractDDPolicy
QuasiReduced <: AbstractDDPolicy

A singleton to express the DD policy. FullyReduced is to reduce the redundant tree.
For example, in the case of BDD, the node that are pointed by both 0 and 1 arrows is omitted.
QuasiReduced is only to reduce the node having the same children.
"""

struct FullyReduced <: AbstractDDPolicy end
struct QuasiReduced <: AbstractDDPolicy end

"""
Show
"""

# function Base.show(io::IO, ::MIME"text/plain", f::BDDValue{V}) where {V}
#     println(io, objectid(f))
# #     @printf(io, "Value: %s (id: %s)\n", f.val, objectid(f))
# end

function Base.show(io::IO, f::DDValue{Tv,Ti}) where {Tv,Ti}
    println(io, f.val)
end

function Base.show(io::IO, ::MIME"text/plain", f::DDVariable{Tv,Ti,N}) where {Tv,Ti,N}
    @printf(io, "variable: %s %s\n", f.label, [objectid(x) for x in f.nodes])
end

function Base.show(io::IO, ::MIME"text/plain", forest::AbstractDDForest{Tv,Ti,Tl}) where {Tv,Ti,Tl}
    @printf(io, "values: %s\n", [x for x in keys(forest.vals)])
#     @printf(io, "vartype: %s\n", typeof(forest.vars))
    @printf(io, "variables: %s\n", [x for x in forest.vars])
    @printf(io, "policy: %s\n", forest.policy)
end

"""
defvar!(forest, label, level, domain)

Define a variable of DD. `label` is a symbol of variable. `level` is an instance of DDLevel.
In DD, the variable is sorted by DDLevel. The node with highest level is placed at top of DD.
`domain` is an instance of DDDomain to represent the values that the variable can take.
"""

function defvar!(forest::AbstractDDForest{Tv,Ti,Tl},
        label::Symbol,
        level::Tl,
        domain::DDDomain{Ti}) where {Tv,Ti,Tl}
    @assert !haskey(forest.vars, label)
    forest.vars[label] = (level, domain)
    nothing
end

"""
defval!(forest, val)

Define a value of DD.
"""

function defval!(forest::AbstractDDForest{Tv,Ti,Tl}, val::Tv) where {Tv,Ti,Tl}
    @assert !haskey(forest.vals, val)
    forest.vals[val] = DDValue{Tv,Ti}(val)
    nothing
end

"""
ddval!(forest, val)

Get a DD node that corresponds to a given value. If it does not exist a corresponding node,
it creates in the DD.
"""

function ddval!(forest::AbstractDDForest{Tv,Ti,Tl}, val::Tv) where {Tv,Ti,Tl}
    get(forest.vals, val) do
        forest.vals[val] = defval!(forest, val)
    end
end

"""
ddvar!(forest, label, nodes)

Get a DD node that corresponds to a given varialbe. If it does not exist a corresponding node,
it creates in the DD.
"""

function ddvar!(forest::AbstractDDForest{Tv,Ti,Tl},
        label::Symbol,
        nodes::Vararg{AbstractDDNode{Tv,Ti},N})::AbstractDDNode{Tv,Ti} where {Tv,Ti,Tl,N}
    return _ddvar!(forest.policy, forest, label, nodes)
end

function _ddvar!(::FullyReduced,
        forest::AbstractDDForest{Tv,Ti,Tl},
        label::Symbol,
        nodes::NTuple{N,AbstractDDNode{Tv,Ti}})::AbstractDDNode{Tv,Ti} where {Tv,Ti,Tl,N}
    level, domain = forest.vars[label]
    @assert size(domain) == length(nodes)

    key = (label, nodes)
    get(forest.varcache, key) do
        forest.varcache[key] = _ddreduce(forest, label, nodes)
#         if _issame(nodes)
#             nodes[1]
#         else
#             forest.varcache[key] = DDVariable{Tv,Ti,Tl,N}(forest, label, nodes...)
#         end
    end
end

function _ddvar!(::QuasiReduced,
        forest::AbstractDDForest{Tv,Ti,Tl},
        label::Symbol,
        nodes::NTuple{N,AbstractDDNode{Tv,Ti}})::AbstractDDNode{Tv,Ti} where {Tv,Ti,Tl,N}
    level, domain = forest.vars[label]
    @assert size(domain) == length(nodes)

    key = (label, nodes)
    get(forest.varcache, key) do
        forest.varcache[key] = DDVariable{Tv,Ti,N}(label, nodes...)
    end
end

"""
apply!(forest, op, f)
apply!(forest, op, f, g)

Perform an apply operation.
"""

function apply!(forest::AbstractDDForest{Tv,Ti,Tl},
        op::AbstractUnaryDDOperator,
        f::AbstractDDNode{Tv,Ti}) where {Tv,Ti,Tl}
    opkey = (op,(f,))
    get(forest.opcache, opkey) do
        forest.opcache[opkey] = _apply!(forest.policy, forest, op, f)
    end
end

function apply!(forest::AbstractDDForest{Tv,Ti,Tl},
        op::AbstractBinaryDDOperator,
        f::AbstractDDNode{Tv,Ti},
        g::AbstractDDNode{Tv,Ti}) where {Tv,Ti,Tl}
    opkey = (op,(f,g))
    get(forest.opcache, opkey) do
        forest.opcache[opkey] = _apply!(forest.policy, forest, op, f, g)
    end
end

"""
Unary operator
"""

function _apply!(::AbstractDDPolicy,
        forest::AbstractDDForest{Tv,Ti,Tl},
        op::AbstractUnaryDDOperator,
        f::AbstractDDNode{Tv,Ti}) where {Tv,Ti,Tl}
    res = [apply!(forest, op, x) for x = f.nodes]
    return ddvar!(forest, f.label, res...)
end

"""
Binary operator
"""

function _apply!(::FullyReduced,
        forest::AbstractDDForest{Tv,Ti,Tl},
        op::AbstractBinaryDDOperator,
        f::DDVariable{Tv,Ti},
        g::DDVariable{Tv,Ti}) where {Tv,Ti,Tl}
    flevel, fdomain = forest.vars[f.label]
    glevel, gdomain = forest.vars[g.label]
    if flevel == glevel
        res = [apply!(forest, op, x[1], x[2]) for x = zip(f.nodes, g.nodes)]
        ddvar!(forest, f.label, res...)
    elseif flevel > glevel
        res = [apply!(forest, op, x, g) for x = f.nodes]
        ddvar!(forest, f.label, res...)
    elseif flevel < glevel
        res = [apply!(forest, op, f, x) for x = g.nodes]
        ddvar!(forest, g.label, res...)
    end
end

function _apply!(::QuasiReduced,
        forest::AbstractDDForest{Tv,Ti,Tl},
        op::AbstractBinaryDDOperator,
        f::DDVariable{Tv,Ti},
        g::DDVariable{Tv,Ti}) where {Tv,Ti,Tl}
    res = [apply!(forest, op, x[1], x[2]) for x = zip(f.nodes, g.nodes)]
    ddvar!(forest, f.label, res...)
end

