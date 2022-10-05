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

const HeaderID = UInt
const NodeID = UInt
const LevelT = Int
const DomainT = Int
const ValueT = Int

abstract type AbstractOperator end

struct MDDMin <: AbstractOperator end
struct MDDMax <: AbstractOperator end
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
    cache::Dict{Tuple{AbstractOperator,NodeID,NodeID},AbstractNode}

    function MDDForest()
        mgr = NodeManager(0)
        ut = Dict{Tuple{HeaderID,Vector{NodeID}},AbstractNode}()
        vt = Dict{ValueT,AbstractNode}()
        zero = Terminal{Bool}(_get_next!(mgr), false)
        one = Terminal{Bool}(_get_next!(mgr), true)
        cache = Dict{Tuple{AbstractOperator,NodeID,NodeID},AbstractNode}()
        new(mgr, ut, vt, zero, one, cache)
    end
end

"""
struct
"""

mutable struct NodeHeader
    id::HeaderID
    level::LevelT
    domain::DomainT

    function NodeHeader(level::LevelT, domain::DomainT)
        new(level, level, domain)
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

function val!(b::MDDForest, value::ValueT)
    Terminal(b, value)
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

## min

function _apply!(b::MDDForest, ::MDDMin, f::Terminal{ValueT}, g::Terminal{ValueT})
    Terminal(b, min(f.value, g.value))
end

## max

function _apply!(b::MDDForest, ::MDDMax, f::Terminal{ValueT}, g::Terminal{ValueT})
    Terminal(b, max(f.value, g.value))
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

function _apply!(b::MDDForest, ::MDDAnd, f::Terminal{Bool}, g::Node)
    # assume f.value, g.value are bool
    if f.value == true
        g
    else
        b.zero
    end
end

function _apply!(b::MDDForest, ::MDDAnd, f::Node, g::Terminal{Bool})
    # assume f.value, g.value are bool
    if g.value == true
        f
    else
        b.zero
    end
end

function _apply!(b::MDDForest, ::MDDAnd, f::Terminal{Bool}, g::Terminal{Bool})
    # assume f.value, g.value are bool
    Terminal(b, f.value && g.value)
end

## or

function _apply!(b::MDDForest, ::MDDOr, f::Terminal{Bool}, g::Node)
    # assume f.value, g.value are bool
    if f.value == false
        g
    else
        b.one
    end
end

function _apply!(b::MDDForest, ::MDDOr, f::Node, g::Terminal{Bool})
    # assume f.value, g.value are bool
    if g.value == false
        f
    else
        b.one
    end
end

function _apply!(b::MDDForest, ::MDDOr, f::Terminal{Bool}, g::Terminal{Bool})
    # assume f.value, g.value are bool
    Terminal(b, f.value || g.value)
end

## if

function _apply!(b::MDDForest, ::MDDIf, f::Terminal{Bool}, g::Terminal{ValueT})
    # assume f.value is bool, g.value is integer
    if f.value == true
        g
    else
        f
    end
end

## else

function _apply!(b::MDDForest, ::MDDElse, f::Terminal{Bool}, g::Terminal{ValueT})
    # assume f.value is bool, g.value is integer
    if f.value == false
        g
    else
        f
    end
end

## Union

function _apply!(b::MDDForest, ::MDDUnion, f::Terminal{Bool}, g::Terminal{ValueT})
    g
end

function _apply!(b::MDDForest, ::MDDUnion, f::Terminal{ValueT}, g::Terminal{Bool})
    f
end

function _apply!(b::MDDForest, ::MDDUnion, f::Terminal{ValueT}, g::Terminal{ValueT})
    throw(ErrorException("There exists a conflict condition."))
end

function _apply!(b::MDDForest, ::MDDUnion, f::Terminal{Bool}, g::Terminal{Bool})
    throw(ErrorException("There exists a undermined condition."))
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
    println(io, "\"obj$(f.id)\" [shape = circle, label = \"$(f.header.level)\"];")
    for i = 1:f.header.domain
        _todot!(b, f.nodes[i], visited, io)
        println(io, "\"obj$(f.id)\" -> \"obj$(f.nodes[i].id)\" [label = \"$(i)\"];")
    end
    push!(visited, f)
    nothing
end

### operations

function lt!(b::MDDForest, f::AbstractNode, g::AbstractNode)
    apply!(b, MDDLT(), f, g)
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

include("_mss.jl")

end
