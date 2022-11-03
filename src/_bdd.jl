"""
BDD Module
"""

module BDD

export bdd

abstract type AbstractNode end
abstract type AbstractTerminal <: AbstractNode end

function Base.show(io::IO, n::AbstractNode)
    Base.show(io, "node$(n.id)")
end

"""
type alias
"""

const NodeID = UInt
const LevelT = Int

abstract type AbstractOperator end

struct BDDNot <: AbstractOperator end
struct BDDAnd <: AbstractOperator end
struct BDDOr <: AbstractOperator end
struct BDDXor <: AbstractOperator end
struct BDDEq <: AbstractOperator end
struct BDDNeq <: AbstractOperator end

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

mutable struct BDDForest
    mgr::NodeManager
    hmgr::NodeManager
    utable::Dict{Tuple{NodeID,NodeID,NodeID},AbstractNode}
    zero::AbstractTerminal
    one::AbstractTerminal
    cache::Dict{Tuple{AbstractOperator,NodeID,NodeID},AbstractNode}

    function BDDForest()
        b = new()
        b.mgr = NodeManager(0)
        b.hmgr = NodeManager(0)
        b.utable = Dict{Tuple{NodeID,NodeID,NodeID},AbstractNode}()
        b.zero = Terminal(b, _get_next!(b.mgr), false)
        b.one = Terminal(b, _get_next!(b.mgr), true)
        b.cache = Dict{Tuple{AbstractOperator,NodeID,NodeID},AbstractNode}()
        b
    end
end

"""
struct
"""

mutable struct NodeHeader
    id::NodeID
    level::LevelT
    label::Symbol

    function NodeHeader(id::NodeID, level::LevelT, label::Symbol)
        new(id, level, label)
    end
end

mutable struct Node <: AbstractNode
    b::BDDForest
    id::NodeID
    header::NodeHeader
    low::AbstractNode
    high::AbstractNode

    function Node(b::BDDForest, h::NodeHeader, low::AbstractNode, high::AbstractNode)
        if low.id == high.id
            return low
        end
        key = (h.id, low.id, high.id)
        get(b.utable, key) do
            id = _get_next!(b.mgr)
            b.utable[key] = new(b, id, h, low, high)
        end
    end
end

struct Terminal <: AbstractTerminal
    b::BDDForest
    id::NodeID
    value::Bool
end

function Terminal(b::BDDForest, value::Bool)
    if value == true
        b.one
    else
        b.zero
    end
end

function getdd(f::AbstractNode)
    f.b
end

"""
uniapply

Apply operation for unioperator
"""

function apply!(b::BDDForest, op::AbstractOperator, f::AbstractNode)
    return _apply!(b, op, f)
end

function _apply!(b::BDDForest, op::AbstractOperator, f::Node)
    key = (op, f.id, b.zero.id)
    get(b.cache, key) do
        low = _apply!(b, op, f.low)
        high = _apply!(b, op, f.high)
        ans = Node(b, f.header, low, high)
        b.cache[key] = ans
    end
end

function _apply!(b::BDDForest, ::BDDNot, f::Terminal)
    Terminal(b, !f.value)
end

"""
apply

Apply operation for binoperator
"""

function apply!(b::BDDForest, op::AbstractOperator, f::AbstractNode, g::AbstractNode)
    return _apply!(b, op, f, g)
end

function _apply!(b::BDDForest, op::AbstractOperator, f::Node, g::Node)
    key = (op, f.id, g.id)
    get(b.cache, key) do
        if f.header.level > g.header.level
            low = _apply!(b, op, f.low, g)
            high = _apply!(b, op, f.high, g)
            ans = Node(b, f.header, low, high)
        elseif f.header.level < g.header.level
            low = _apply!(b, op, f, g.low)
            high = _apply!(b, op, f, g.high)
            ans = Node(b, g.header, low, high)
        else
            low = _apply!(b, op, f.low, g.low)
            high = _apply!(b, op, f.high, g.high)
            ans = Node(b, f.header, low, high)
        end
        b.cache[key] = ans
    end
end

function _apply!(b::BDDForest, op::AbstractOperator, f::AbstractTerminal, g::Node)
    key = (op, f.id, g.id)
    get(b.cache, key) do
        low = _apply!(b, op, f, g.low)
        high = _apply!(b, op, f, g.high)
        ans = Node(b, g.header, low, high)
        b.cache[key] = ans
    end
end

function _apply!(b::BDDForest, op::AbstractOperator, f::Node, g::AbstractTerminal)
    key = (op, f.id, g.id)
    get(b.cache, key) do
        low = _apply!(b, op, f.low, g)
        high = _apply!(b, op, f.high, g)
        ans = Node(b, f.header, low, high)
        b.cache[key] = ans
    end
end

## Eq

function _apply!(b::BDDForest, ::BDDEq, f::Terminal, g::Terminal)
    Terminal(b, f.value == g.value)
end

## Neq

function _apply!(b::BDDForest, ::BDDNeq, f::Terminal, g::Terminal)
    Terminal(b, f.value != g.value)
end

## and

function _apply!(b::BDDForest, ::BDDAnd, f::Terminal, g::Node)
    # assume f.value, g.value are bool
    if f.value == true
        g
    else
        b.zero
    end
end

function _apply!(b::BDDForest, ::BDDAnd, f::Node, g::Terminal)
    # assume f.value, g.value are bool
    if g.value == true
        f
    else
        b.zero
    end
end

function _apply!(b::BDDForest, ::BDDAnd, f::Terminal, g::Terminal)
    # assume f.value, g.value are bool
    Terminal(b, f.value && g.value)
end

## or

function _apply!(b::BDDForest, ::BDDOr, f::Terminal, g::Node)
    # assume f.value, g.value are bool
    if f.value == false
        g
    else
        b.one
    end
end

function _apply!(b::BDDForest, ::BDDOr, f::Node, g::Terminal)
    # assume f.value, g.value are bool
    if g.value == false
        f
    else
        b.one
    end
end

function _apply!(b::BDDForest, ::BDDOr, f::Terminal, g::Terminal)
    # assume f.value, g.value are bool
    Terminal(b, f.value || g.value)
end

## xor

function _apply!(b::BDDForest, ::BDDXor, f::Terminal, g::Terminal)
    # assume f.value, g.value are bool
    if f.value == g.value
        Terminal(b, false)
    else
        Terminal(b, true)
    end
end

"""
todot(forest, f)
Return a string for dot to draw a diagram.
"""

function todot(b::BDDForest, f::AbstractNode)
    io = IOBuffer()
    visited = Set{NodeID}()
    println(io, "digraph { layout=dot; overlap=false; splines=true; node [fontsize=10];")
    _todot!(b, f, visited, io)
    println(io, "}")
    String(take!(io))
end

function _todot!(b::BDDForest, f::AbstractTerminal, visited::Set{NodeID}, io::IO)
    if in(f.id, visited)
        return
    end
    println(io, "\"obj$(f.id)\" [shape = square, label = \"$(ifelse(f.value, 1, 0))\"];")
    push!(visited, f.id)
    nothing
end

function _todot!(b::BDDForest, f::Node, visited::Set{NodeID}, io::IO)
    if in(f.id, visited)
        return
    end
    println(io, "\"obj$(f.id)\" [shape = circle, label = \"$(f.header.label)\"];")
    _todot!(b, f.low, visited, io)
    println(io, "\"obj$(f.id)\" -> \"obj$(f.low.id)\" [label = \"0\"];")
    _todot!(b, f.high, visited, io)
    println(io, "\"obj$(f.id)\" -> \"obj$(f.high.id)\" [label = \"1\"];")
    push!(visited, f.id)
    nothing
end

### utilities

bdd() = BDDForest()

function var!(b::BDDForest, name::Symbol, level::LevelT)
    h = NodeHeader(_get_next!(b.hmgr), level, name)
    Node(b, h, Terminal(b, false), Terminal(b, true))
end

eq!(b::BDDForest, f::AbstractNode, g::AbstractNode) = apply!(b, BDDEq(), f, g)
neq!(b::BDDForest, f::AbstractNode, g::AbstractNode) = apply!(b, BDDXor(), f, g)

function and!(b::BDDForest, x::AbstractNode, xs...)
    tmp = x
    for u = xs
        tmp = apply!(b, BDDAnd(), tmp, u)
    end
    tmp
end

function or!(b::BDDForest, x::AbstractNode, xs...)
    tmp = x
    for u = xs
        tmp = apply!(b, BDDOr(), tmp, u)
    end
    tmp
end

function and(x::AbstractNode, xs...)
    b = getdd(x)
    and!(b, x, xs...)
end

function or(x::AbstractNode, xs...)
    b = getdd(x)
    or!(b, x, xs...)
end

not!(b::BDDForest, f::AbstractNode) = apply!(b, BDDNot(), f)

xor!(b::BDDForest, f::AbstractNode, g::AbstractNode) = apply!(b, BDDXor(), f, g)
xor(f::AbstractNode, g::AbstractNode) = xor!(getdd(f), f, g)
xor(f::Bool, g::AbstractNode) = xor!(getdd(g), Terminal(getdd(g), f), g)
xor(f::AbstractNode, g::Bool) = xor!(getdd(f), f, Terminal(getdd(f), g))

imp!(b::BDDForest, f::AbstractNode, g::AbstractNode) = or!(b, not!(b, f), g)
imp(f::AbstractNode, g::AbstractNode) = imp!(getdd(f), f, g)
imp(f::Bool, g::AbstractNode) = imp!(getdd(g), Terminal(getdd(g), f), g)
imp(f::AbstractNode, g::Bool) = imp!(getdd(f), f, Terminal(getdd(f), g))

ifthenelse!(b::BDDForest, f::AbstractNode, g::AbstractNode, h::AbstractNode) = or!(b, and!(b, f, g), and!(b, not!(b, f), h))
ifthenelse(f::AbstractNode, g::AbstractNode, h::AbstractNode) = ifthenelse!(getdd(f), f, g, h)
ifthenelse(f::AbstractNode, g::Bool, h::AbstractNode) = ifthenelse!(getdd(f), f, Terminal(getdd(f), g), h)
ifthenelse(f::AbstractNode, g::AbstractNode, h::Bool) = ifthenelse!(getdd(f), f, g, Terminal(getdd(f), h))
ifthenelse(f::AbstractNode, g::Bool, h::Bool) = ifthenelse!(getdd(f), f, Terminal(getdd(f), g), Terminal(getdd(f), h))
ifthenelse(f::Bool, g::Bool, h::AbstractNode) = ifthenelse!(getdd(h), Terminal(getdd(g), f), Terminal(getdd(g), g), h)
ifthenelse(f::Bool, g::AbstractNode, h::Bool) = ifthenelse!(getdd(g), Terminal(getdd(g), f), g, Terminal(getdd(g), h))
ifthenelse(f::Bool, g::Bool, h::Bool) = ifelse(f, g, h)


ops = [:(==), :(!=), :(&), :(|), :(⊻), :(*), :(+)]
fns = [:eq!, :xor!, :and!, :or!, :xor!, :and!, :or!]

for (op, fn) = zip(ops, fns)
    @eval Base.$op(x::AbstractNode, y::AbstractNode) = $fn(getdd(x), x, y)
    @eval Base.$op(x::AbstractNode, y::Bool) = $fn(getdd(x), x, Terminal(getdd(x), y))
    @eval Base.$op(x::Bool, y::AbstractNode) = $fn(getdd(y), Terminal(getdd(y), x), y)
end

Base.:(!)(x::AbstractNode) = not!(getdd(x), x)
Base.:(~)(x::AbstractNode) = not!(getdd(x), x)
todot(f::AbstractNode) = todot(getdd(f), f)

end
