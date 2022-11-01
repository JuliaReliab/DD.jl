"""
MDD Module
"""

module MDD

import Base
#export bdd, header!, var!, node!, not, and, or, xor, imp, ite, todot

"""
AbstractNode{Ts}

An abstract node for BDD. The parameter Ts represents a type for a symbol of variable.
Ts is usually Symbol.
"""

abstract type AbstractNode end
abstract type AbstractTerminal <: AbstractNode end

function Base.show(io::IO, n::AbstractNode)
    Base.show(io, "node$(n.id)")
end

"""
type alias
"""

struct Undetermined end

const HeaderID = UInt
const NodeID = UInt
const LevelT = Int
const DomainT = Int
const ValueT = Int

abstract type AbstractOperator end

struct MDDMin <: AbstractOperator end
struct MDDMax <: AbstractOperator end

struct MDDPlus <: AbstractOperator end
struct MDDMinus <: AbstractOperator end
struct MDDMul <: AbstractOperator end

struct MDDLte <: AbstractOperator end
struct MDDLt <: AbstractOperator end
struct MDDGte <: AbstractOperator end
struct MDDGt <: AbstractOperator end
struct MDDEq <: AbstractOperator end
struct MDDNeq <: AbstractOperator end

struct MDDAnd <: AbstractOperator end
struct MDDOr <: AbstractOperator end
struct MDDNot <: AbstractOperator end

struct MDDIf <: AbstractOperator end
struct MDDElse <: AbstractOperator end
struct MDDUnion <: AbstractOperator end

mutable struct NodeManager
    nextid::NodeID
end

function _get_next!(mgr::NodeManager)::NodeID
    id = mgr.nextid
    mgr.nextid += 1
    id
end

"""
Forest

A structure to store the information on DD.

Todo: Get rid of `mutable` (export `totalnodeid` to BDDNodeManager?)
"""

mutable struct MDDForest
    mgr::NodeManager
    utable::Dict{Tuple{HeaderID,Vector{NodeID}},AbstractNode}
    vtable::Dict{ValueT,AbstractNode}
    zero::AbstractTerminal
    one::AbstractTerminal
    undetermined::AbstractTerminal
    cache::Dict{Tuple{AbstractOperator,NodeID,NodeID},AbstractNode}

    function MDDForest()
        mgr = NodeManager(0)
        ut = Dict{Tuple{HeaderID,Vector{NodeID}},AbstractNode}()
        vt = Dict{ValueT,AbstractNode}()
        zero = Terminal{Bool}(_get_next!(mgr), false)
        one = Terminal{Bool}(_get_next!(mgr), true)
        undetermined = Terminal{Undetermined}(_get_next!(mgr), Undetermined())
        cache = Dict{Tuple{AbstractOperator,NodeID,NodeID},AbstractNode}()
        new(mgr, ut, vt, zero, one, undetermined, cache)
    end
end

"""
struct
"""

mutable struct NodeHeader
    id::HeaderID
    level::LevelT
    domain::DomainT
    label::Symbol
    domainLabels::Vector{DomainT}
    index::Dict{DomainT,Int}

    function NodeHeader(level::LevelT, domain::DomainT)
        new(level, level, domain, Symbol(level), [i for i = 1:domain], Dict([i => i for i = 1:domain]...))
    end

    function NodeHeader(level::LevelT, label::Symbol, domain::Vector{DomainT})
        new(level, level, length(domain), label, domain, Dict([x => i for (i,x) = enumerate(domain)]...))
    end
end

mutable struct Node <: AbstractNode
    id::NodeID
    header::NodeHeader
    nodes::Vector{AbstractNode}

    function Node(b::MDDForest, h::NodeHeader, nodes::Vector{AbstractNode})
        if _issame(nodes)
            return nodes[1]
        end
        key = (h.id, [x.id for x = nodes])
        get(b.utable, key) do
            id = _get_next!(b.mgr)
            b.utable[key] = new(id, h, nodes)
        end
    end
end

function _issame(nodes::Vector{AbstractNode})
    # assume length(nodes) >= 2
    tmp = nodes[1]
    for x = nodes[2:end]
        if tmp.id != x.id
            return false
        end
    end
    return true
end

struct Terminal{Tv} <: AbstractTerminal
    id::NodeID
    value::Tv
end

function Terminal(b::MDDForest, value::ValueT)
    get(b.vtable, value) do
        id = _get_next!(b.mgr)
        b.vtable[value] = Terminal{ValueT}(id, value)
    end
end

function Terminal(b::MDDForest, value::Bool)
    if value == true
        b.one
    else
        b.zero
    end
end

function Terminal(b::MDDForest, value::Symbol)
    if value == :None
        b.undetermined
    elseif value == :Union
        b.union
    else
        throw(ErrorException("Specaial Symbols are None or Union."))
    end
end

"""
uniapply

Apply operation for unioperator
"""

function apply!(b::MDDForest, op::AbstractOperator, f::AbstractNode)
    return _apply!(b, op, f)
end

function _apply!(b::MDDForest, op::AbstractOperator, f::Node)
    key = (op, f.id, 0)
    get(b.cache, key) do
        nodes = AbstractNode[_apply!(b, op, f.nodes[i]) for i = 1:f.header.domain]
        ans = Node(b, f.header, nodes)
        b.cache[key] = ans
    end
end

function _apply!(b::MDDForest, ::MDDNot, f::Terminal{Bool})
    Terminal(b, !f.value)
end

"""
apply

Apply operation for binoperator
"""

function apply!(b::MDDForest, op::AbstractOperator, f::AbstractNode, g::AbstractNode)
    return _apply!(b, op, f, g)
end

function _apply!(b::MDDForest, op::AbstractOperator, f::Node, g::Node)
    key = (op, f.id, g.id)
    get(b.cache, key) do
        if f.header.level > g.header.level
            nodes = AbstractNode[_apply!(b, op, f.nodes[i], g) for i = 1:f.header.domain]
            ans = Node(b, f.header, nodes)
        elseif f.header.level < g.header.level
            nodes = AbstractNode[_apply!(b, op, f, g.nodes[i]) for i = 1:g.header.domain]
            ans = Node(b, g.header, nodes)
        else
            nodes = AbstractNode[_apply!(b, op, f.nodes[i], g.nodes[i]) for i = 1:f.header.domain]
            ans = Node(b, f.header, nodes)
        end
        b.cache[key] = ans
    end
end

function _apply!(b::MDDForest, op::AbstractOperator, f::AbstractTerminal, g::Node)
    key = (op, f.id, g.id)
    get(b.cache, key) do
        nodes = AbstractNode[_apply!(b, op, f, g.nodes[i]) for i = 1:g.header.domain]
        ans = Node(b, g.header, nodes)
        b.cache[key] = ans
    end
end

function _apply!(b::MDDForest, op::AbstractOperator, f::Node, g::AbstractTerminal)
    key = (op, f.id, g.id)
    get(b.cache, key) do
        nodes = AbstractNode[_apply!(b, op, f.nodes[i], g) for i = 1:f.header.domain]
        ans = Node(b, f.header, nodes)
        b.cache[key] = ans
    end
end

for op = [:MDDMin, :MDDMax, :MDDPlus, :MDDMinus, :MDDMul, :MDDLte, :MDDLt, :MDDGte, :MDDGt, :MDDEq, :MDDNeq]
    @eval function _apply!(b::MDDForest, ::$op, ::Terminal{ValueT}, ::Terminal{Undetermined})
        b.undetermined
    end
    @eval function _apply!(b::MDDForest, ::$op, ::Terminal{Undetermined}, ::Terminal{ValueT})
        b.undetermined
    end
    @eval function _apply!(b::MDDForest, ::$op, ::Terminal{Undetermined}, ::Terminal{Undetermined})
        b.undetermined
    end
end

for op = [:MDDAnd, :MDDOr]
    @eval function _apply!(b::MDDForest, ::$op, ::Terminal{Bool}, ::Terminal{Undetermined})
        b.undetermined
    end
    @eval function _apply!(b::MDDForest, ::$op, ::Terminal{Undetermined}, ::Terminal{Bool})
        b.undetermined
    end
    @eval function _apply!(b::MDDForest, ::$op, ::Terminal{Bool}, ::Terminal{Undetermined})
        b.undetermined
    end
    @eval function _apply!(b::MDDForest, ::$op, ::Terminal{Undetermined}, ::Terminal{Undetermined})
        b.undetermined
    end
end

## min

function _apply!(b::MDDForest, ::MDDMin, f::Terminal{ValueT}, g::Terminal{ValueT})
    Terminal(b, min(f.value, g.value))
end

## max

function _apply!(b::MDDForest, ::MDDMax, f::Terminal{ValueT}, g::Terminal{ValueT})
    Terminal(b, max(f.value, g.value))
end

## Plus

function _apply!(b::MDDForest, ::MDDPlus, f::Terminal{ValueT}, g::Terminal{ValueT})
    Terminal(b, f.value + g.value)
end

## Minus

function _apply!(b::MDDForest, ::MDDMinus, f::Terminal{ValueT}, g::Terminal{ValueT})
    Terminal(b, f.value - g.value)
end

## Mul

function _apply!(b::MDDForest, ::MDDMul, f::Terminal{ValueT}, g::Terminal{ValueT})
    Terminal(b, f.value * g.value)
end

## Lte

function _apply!(b::MDDForest, ::MDDLte, f::Terminal{ValueT}, g::Terminal{ValueT})
    Terminal(b, f.value <= g.value)
end

## Lt

function _apply!(b::MDDForest, ::MDDLt, f::Terminal{ValueT}, g::Terminal{ValueT})
    Terminal(b, f.value < g.value)
end

## Gte

function _apply!(b::MDDForest, ::MDDGte, f::Terminal{ValueT}, g::Terminal{ValueT})
    Terminal(b, f.value >= g.value)
end

## Gt

function _apply!(b::MDDForest, ::MDDGt, f::Terminal{ValueT}, g::Terminal{ValueT})
    Terminal(b, f.value > g.value)
end

## Eq

function _apply!(b::MDDForest, ::MDDEq, f::Terminal{ValueT}, g::Terminal{ValueT})
    Terminal(b, f.value == g.value)
end

## Neq

function _apply!(b::MDDForest, ::MDDNeq, f::Terminal{ValueT}, g::Terminal{ValueT})
    Terminal(b, f.value != g.value)
end

## and

# function _apply!(b::MDDForest, ::MDDAnd, f::Terminal{Bool}, g::Node)
#     # assume f.value, g.value are bool
#     if f.value == true
#         g
#     else
#         b.zero
#     end
# end

# function _apply!(b::MDDForest, ::MDDAnd, f::Node, g::Terminal{Bool})
#     # assume f.value, g.value are bool
#     if g.value == true
#         f
#     else
#         b.zero
#     end
# end

function _apply!(b::MDDForest, ::MDDAnd, f::Terminal{Bool}, g::Terminal{Bool})
    # assume f.value, g.value are bool
    Terminal(b, f.value && g.value)
end

## or

# function _apply!(b::MDDForest, ::MDDOr, f::Terminal{Bool}, g::Node)
#     # assume f.value, g.value are bool
#     if f.value == false
#         g
#     else
#         b.one
#     end
# end

# function _apply!(b::MDDForest, ::MDDOr, f::Node, g::Terminal{Bool})
#     # assume f.value, g.value are bool
#     if g.value == false
#         f
#     else
#         b.one
#     end
# end

function _apply!(b::MDDForest, ::MDDOr, f::Terminal{Bool}, g::Terminal{Bool})
    # assume f.value, g.value are bool
    Terminal(b, f.value || g.value)
end

####### if

function _apply!(b::MDDForest, ::MDDIf, f::Terminal{Bool}, g::Terminal{Tx}) where Tx <: Union{ValueT, Bool, Undetermined}
    # assume f.value is bool, g.value is integer
    if f.value == true
        g
    else
        b.undetermined
    end
end

function _apply!(b::MDDForest, ::MDDIf, f::Terminal{Undetermined}, g::AbstractTerminal)
    b.undetermined
end

## else

function _apply!(b::MDDForest, ::MDDElse, f::Terminal{Bool}, g::Terminal{Tx}) where Tx <: Union{ValueT, Bool, Undetermined}
    # assume f.value is bool, g.value is integer
    if f.value == false
        g
    else
        b.undetermined
    end
end

function _apply!(b::MDDForest, ::MDDElse, f::Terminal{Undetermined}, g::AbstractTerminal)
    b.undetermined
end

## Union

function _apply!(b::MDDForest, ::MDDUnion, f::Terminal{Undetermined}, g::Terminal{Tx}) where Tx <: Union{ValueT, Bool}
    g
end

function _apply!(b::MDDForest, ::MDDUnion, f::Terminal{Tx}, g::Terminal{Undetermined}) where Tx <: Union{ValueT, Bool}
    f
end

function _apply!(b::MDDForest, ::MDDUnion, f::Terminal{Tx}, g::Terminal{Ty}) where {Tx <: Union{ValueT, Bool}, Ty <: Union{ValueT, Bool}}
    throw(ErrorException("There exists a conflict condition."))
end

function _apply!(b::MDDForest, ::MDDUnion, f::Terminal{Undetermined}, g::Terminal{Undetermined})
    b.undetermined
end

"""
todot(forest, f)
Return a string for dot to draw a diagram.
"""

function todot(b::MDDForest, f::AbstractNode)
    io = IOBuffer()
    visited = Set{AbstractNode}()
    println(io, "digraph { layout=dot; overlap=false; splines=true; node [fontsize=10];")
    _todot!(b, f, visited, io)
    println(io, "}")
    String(take!(io))
end

function _todot!(b::MDDForest, f::AbstractTerminal, visited::Set{AbstractNode}, io::IO)
    if in(f, visited)
        return
    end
    println(io, "\"obj$(f.id)\" [shape = square, label = \"$(f.value)\"];")
    push!(visited, f)
    nothing
end

function _todot!(b::MDDForest, f::Node, visited::Set{AbstractNode}, io::IO)
    if in(f, visited)
        return
    end
    println(io, "\"obj$(f.id)\" [shape = circle, label = \"$(f.header.label)\"];")
    for (i,x) = enumerate(f.header.domainLabels)
        if f.nodes[i] != b.undetermined
            _todot!(b, f.nodes[i], visited, io)
            println(io, "\"obj$(f.id)\" -> \"obj$(f.nodes[i].id)\" [label = \"$(x)\"];")
        end
    end
    push!(visited, f)
    nothing
end

"""
prob(forest, f)
"""

function prob(b::MDDForest, f::AbstractNode, pr::Dict{NodeHeader,Vector{Float64}}, value::Tv) where Tv
    cache = Dict{AbstractNode,Float64}()
    _prob!(b, f, pr, cache, value)
end

function _prob!(b::MDDForest, f::AbstractTerminal, pr::Dict{NodeHeader,Vector{Float64}}, cache::Dict{AbstractNode,Float64}, value::Tv) where Tv
    f.value == value && return 1.0
    return 0.0
end

function _prob!(b::MDDForest, f::Node, pr::Dict{NodeHeader,Vector{Float64}}, cache::Dict{AbstractNode,Float64}, value::Tv) where Tv
    get(cache, f) do
        res = 0.0
        fv = pr[f.header]
        for i = 1:f.header.domain
            res += fv[i] * _prob!(b, f.nodes[i], pr, cache, value)
        end
        cache[f] = res
    end
end

"""
getmax(forest, f, lower, upper)
"""

function getmax(b::MDDForest, f::AbstractNode, lower::Vector{ValueT}, upper::Vector{ValueT})
    cache = Dict()
    _getmax!(b, f, lower, upper, cache)
end

function _getmax!(b::MDDForest, f::Terminal{ValueT}, ::Vector{ValueT}, ::Vector{ValueT}, cache)
    [f.value, f.value]
end

function _getmax!(b::MDDForest, f::Terminal{Undetermined}, ::Vector{ValueT}, ::Vector{ValueT}, cache)
    [Undetermined(), Undetermined()]
end

function _getmax!(b::MDDForest, f::Node, lower::Vector{ValueT}, upper::Vector{ValueT}, cache)
    get(cache, f) do
        m = Any[Undetermined(), Undetermined()]
        for i = f.header.index[lower[f.header.level]]:f.header.index[upper[f.header.level]]
            lres, ures = _getmax!(b, f.nodes[i], lower, upper, cache)
            if lres != Undetermined() && (m[1] == Undetermined() || lres < m[1])
                m[1] = lres
            end
            if ures != Undetermined() && (m[2] == Undetermined() || ures > m[2])
                m[2] = ures
            end
        end
        cache[f] = m
    end
end

### operations

function lt!(b::MDDForest, f::AbstractNode, g::AbstractNode)
    apply!(b, MDDLt(), f, g)
end

function lte!(b::MDDForest, f::AbstractNode, g::AbstractNode)
    apply!(b, MDDLte(), f, g)
end

function gt!(b::MDDForest, f::AbstractNode, g::AbstractNode)
    apply!(b, MDDGt(), f, g)
end

function gte!(b::MDDForest, f::AbstractNode, g::AbstractNode)
    apply!(b, MDDGte(), f, g)
end

function eq!(b::MDDForest, f::AbstractNode, g::AbstractNode)
    apply!(b, MDDEq(), f, g)
end

function neq!(b::MDDForest, f::AbstractNode, g::AbstractNode)
    apply!(b, MDDNeq(), f, g)
end

function and!(b::MDDForest, f::AbstractNode, g::AbstractNode)
    apply!(b, MDDAnd(), f, g)
end

function or!(b::MDDForest, f::AbstractNode, g::AbstractNode)
    apply!(b, MDDOr(), f, g)
end

function ifelse!(b::MDDForest, f::AbstractNode, g::AbstractNode, h::AbstractNode)
    tmp1 = apply!(b, MDDIf(), f, g)
    tmp2 = apply!(b, MDDElse(), f, h)
    apply!(b, MDDUnion(), tmp1, tmp2)
end

function match!(b::MDDForest, args::Vararg{Tuple{AbstractNode,AbstractNode}})
    tmp = default
    for x = reverse(args)
        tmp = ifelse!(x[1], x[2], tmp)
    end
    tmp
end

function max!(b::MDDForest, args...)
    tmp = args[1]
    for u = args[2:end]
        tmp = apply!(b, MDDMax(), tmp, u)
    end
    tmp
end

function min!(b::MDDForest, args...)
    tmp = args[1]
    for u = args[2:end]
        tmp = apply!(b, MDDMin(), tmp, u)
    end
    tmp
end

function plus!(b::MDDForest, args...)
    tmp = args[1]
    for u = args[2:end]
        tmp = apply!(b, MDDPlus(), tmp, u)
    end
    tmp
end

function minus!(b::MDDForest, args...)
    tmp = args[1]
    for u = args[2:end]
        tmp = apply!(b, MDDMinus(), tmp, u)
    end
    tmp
end

function mul!(b::MDDForest, args...)
    tmp = args[1]
    for u = args[2:end]
        tmp = apply!(b, MDDMul(), tmp, u)
    end
    tmp
end

include("_mss.jl")

end
