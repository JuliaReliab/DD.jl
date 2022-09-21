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
struct MDDIf <: AbstractOperator end
struct MDDElse <: AbstractOperator end
struct MDDUnion <: AbstractOperator end

struct BinOperator
    op::AbstractOperator
    cache::Dict{Tuple{NodeID,NodeID},AbstractNode}
end

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
    minop::BinOperator
    maxop::BinOperator
    ltop::BinOperator
    lteop::BinOperator
    gtop::BinOperator
    gteop::BinOperator
    eqop::BinOperator
    neqop::BinOperator
    andop::BinOperator
    orop::BinOperator
    ifop::BinOperator
    elseop::BinOperator
    unionop::BinOperator

    function MDDForest()
        mgr = NodeManager(0)
        ut = Dict{Tuple{HeaderID,Vector{NodeID}},AbstractNode}()
        vt = Dict{ValueT,AbstractNode}()
        zero = Terminal{Bool}(_get_next!(mgr), false)
        one = Terminal{Bool}(_get_next!(mgr), true)
        minop = BinOperator(MDDMin(), Dict{Tuple{NodeID,NodeID},AbstractNode}())
        maxop = BinOperator(MDDMax(), Dict{Tuple{NodeID,NodeID},AbstractNode}())
        ltop = BinOperator(MDDLt(), Dict{Tuple{NodeID,NodeID},AbstractNode}())
        lteop = BinOperator(MDDLte(), Dict{Tuple{NodeID,NodeID},AbstractNode}())
        gtop = BinOperator(MDDGt(), Dict{Tuple{NodeID,NodeID},AbstractNode}())
        gteop = BinOperator(MDDGte(), Dict{Tuple{NodeID,NodeID},AbstractNode}())
        eqop = BinOperator(MDDEq(), Dict{Tuple{NodeID,NodeID},AbstractNode}())
        neqop = BinOperator(MDDNeq(), Dict{Tuple{NodeID,NodeID},AbstractNode}())
        andop = BinOperator(MDDAnd(), Dict{Tuple{NodeID,NodeID},AbstractNode}())
        orop = BinOperator(MDDOr(), Dict{Tuple{NodeID,NodeID},AbstractNode}())
        ifop = BinOperator(MDDIf(), Dict{Tuple{NodeID,NodeID},AbstractNode}())
        elseop = BinOperator(MDDElse(), Dict{Tuple{NodeID,NodeID},AbstractNode}())
        unionop = BinOperator(MDDUnion(), Dict{Tuple{NodeID,NodeID},AbstractNode}())
        new(mgr, ut, vt, zero, one,
            minop, maxop, ltop, lteop, gtop, gteop, eqop, neqop, andop, orop, ifop, elseop, unionop)
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
binapply

Apply operation for binoperator
"""

function binapply!(b::MDDForest, op::BinOperator, f::AbstractNode, g::AbstractNode)
    return _binapply!(b, op.op, op, f, g)
end

function _binapply!(b::MDDForest, ::AbstractOperator, op::BinOperator, f::Node, g::Node)
    key = (f.id, g.id)
    get(op.cache, key) do
        if f.header.level > g.header.level
            nodes = AbstractNode[_binapply!(b, op.op, op, f.nodes[i], g) for i = 1:f.header.domain]
            ans = Node(b, f.header, nodes)
        elseif f.header.level < g.header.level
            nodes = AbstractNode[_binapply!(b, op.op, op, f, g.nodes[i]) for i = 1:g.header.domain]
            ans = Node(b, g.header, nodes)
        else
            nodes = AbstractNode[_binapply!(b, op.op, op, f.nodes[i], g.nodes[i]) for i = 1:f.header.domain]
            ans = Node(b, f.header, nodes)
        end
        op.cache[key] = ans
    end
end

function _binapply!(b::MDDForest, ::AbstractOperator, op::BinOperator, f::AbstractTerminal, g::Node)
    key = (f.id, g.id)
    get(op.cache, key) do
        nodes = AbstractNode[_binapply!(b, op.op, op, f, g.nodes[i]) for i = 1:g.header.domain]
        ans = Node(b, g.header, nodes)
        op.cache[key] = ans
    end
end

function _binapply!(b::MDDForest, ::AbstractOperator, op::BinOperator, f::Node, g::AbstractTerminal)
    key = (f.id, g.id)
    get(op.cache, key) do
        nodes = AbstractNode[_binapply!(b, op.op, op, f.nodes[i], g) for i = 1:f.header.domain]
        ans = Node(b, f.header, nodes)
        op.cache[key] = ans
    end
end

## min

function _binapply!(b::MDDForest, ::MDDMin, op::BinOperator, f::Terminal{ValueT}, g::Terminal{ValueT})
    tmp = min(f.value, g.value)
    Terminal(b, tmp)
end

## max

function _binapply!(b::MDDForest, ::MDDMax, op::BinOperator, f::Terminal{ValueT}, g::Terminal{ValueT})
    tmp = max(f.value, g.value)
    Terminal(b, tmp)
end

## Lte

function _binapply!(b::MDDForest, ::MDDLte, op::BinOperator, f::Terminal{ValueT}, g::Terminal{ValueT})
    if f.value <= g.value
        b.one
    else
        b.zero
    end
end

## Lt

function _binapply!(b::MDDForest, ::MDDLt, op::BinOperator, f::Terminal{ValueT}, g::Terminal{ValueT})
    if f.value < g.value
        b.one
    else
        b.zero
    end
end

## Gte

function _binapply!(b::MDDForest, ::MDDGte, op::BinOperator, f::Terminal{ValueT}, g::Terminal{ValueT})
    if f.value >= g.value
        b.one
    else
        b.zero
    end
end

## Gt

function _binapply!(b::MDDForest, ::MDDGt, op::BinOperator, f::Terminal{ValueT}, g::Terminal{ValueT})
    if f.value > g.value
        b.one
    else
        b.zero
    end
end

## Eq

function _binapply!(b::MDDForest, ::MDDEq, op::BinOperator, f::Terminal{ValueT}, g::Terminal{ValueT})
    if f.value == g.value
        b.one
    else
        b.zero
    end
end

## Neq

function _binapply!(b::MDDForest, ::MDDNeq, op::BinOperator, f::Terminal{ValueT}, g::Terminal{ValueT})
    if f.value != g.value
        b.one
    else
        b.zero
    end
end

## and

function _binapply!(b::MDDForest, ::MDDAnd, op::BinOperator, f::Terminal{Bool}, g::Terminal{Bool})
    # assume f.value, g.value are bool
    Terminal(b, f.value && g.value)
end

## or

function _binapply!(b::MDDForest, ::MDDOr, op::BinOperator, f::Terminal{Bool}, g::Terminal{Bool})
    # assume f.value, g.value are bool
    Terminal(b, f.value || g.value)
end

## if

function _binapply!(b::MDDForest, ::MDDIf, op::BinOperator, f::Terminal{Bool}, g::Terminal{ValueT})
    # assume f.value is bool, g.value is integer
    if f.value == true
        g
    else
        f
    end
end

## else

function _binapply!(b::MDDForest, ::MDDElse, op::BinOperator, f::Terminal{Bool}, g::Terminal{ValueT})
    # assume f.value is bool, g.value is integer
    if f.value == false
        g
    else
        f
    end
end

## Union

function _binapply!(b::MDDForest, ::MDDUnion, op::BinOperator, f::Terminal{Bool}, g::Terminal{ValueT})
    g
end

function _binapply!(b::MDDForest, ::MDDUnion, op::BinOperator, f::Terminal{ValueT}, g::Terminal{Bool})
    f
end

function _binapply!(b::MDDForest, ::MDDUnion, op::BinOperator, f::Terminal{ValueT}, g::Terminal{ValueT})
    throw(ErrorException("There exists a conflict condition."))
end

function _binapply!(b::MDDForest, ::MDDUnion, op::BinOperator, f::Terminal{Bool}, g::Terminal{Bool})
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
    binapply!(b, b.ltop, f, g)
end

function lte!(b::MDDForest, f::AbstractNode, g::AbstractNode)
    binapply!(b, b.lteop, f, g)
end

function gt!(b::MDDForest, f::AbstractNode, g::AbstractNode)
    binapply!(b, b.gtop, f, g)
end

function gte!(b::MDDForest, f::AbstractNode, g::AbstractNode)
    binapply!(b, b.gteop, f, g)
end

function eq!(b::MDDForest, f::AbstractNode, g::AbstractNode)
    binapply!(b, b.eqop, f, g)
end

function neq!(b::MDDForest, f::AbstractNode, g::AbstractNode)
    binapply!(b, b.neqop, f, g)
end

function and!(b::MDDForest, f::AbstractNode, g::AbstractNode)
    binapply!(b, b.andop, f, g)
end

function or!(b::MDDForest, f::AbstractNode, g::AbstractNode)
    binapply!(b, b.orop, f, g)
end

function ifelse!(b::MDDForest, f::AbstractNode, g::AbstractNode, h::AbstractNode)
    tmp1 = binapply!(b, b.ifop, f, g)
    tmp2 = binapply!(b, b.elseop, f, h)
    binapply!(b, b.unionop, tmp1, tmp2)
end

include("_mss.jl")

end
