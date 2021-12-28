"""
BDD Module
"""

module BDD

import Base
export bdd, header!, var!, node!, not, and, or, xor, imp, ite, todot

"""
AbstractNode{Ts}

An abstract node for BDD. The parameter Ts represents a type for a symbol of variable.
Ts is usually Symbol.
"""

abstract type AbstractNode{Ts} end

function Base.show(io::IO, n::AbstractNode{Ts}) where Ts
    Base.show(io, "node$(n.id)")
end

"""
type alias
"""

const HeaderID = UInt
const NodeID = UInt

"""
struct
"""

struct NodeHeader{Ts}
    id::HeaderID
    level::Int
    label::Ts
end

struct Node{Ts} <: AbstractNode{Ts}
    id::NodeID
    header::NodeHeader{Ts}
    low::AbstractNode{Ts}
    high::AbstractNode{Ts}
end

struct Terminal{Ts} <: AbstractNode{Ts}
    id::NodeID
end

"""
Operators
"""

abstract type AbstractOperator end

struct BDDNot <: AbstractOperator end
struct BDDAnd <: AbstractOperator end
struct BDDOr <: AbstractOperator end
struct BDDXor <: AbstractOperator end

struct UniOperator{Ts}
    op::AbstractOperator
    cache::Dict{NodeID,AbstractNode{Ts}}
end

struct BinOperator{Ts}
    op::AbstractOperator
    cache::Dict{Tuple{NodeID,NodeID},AbstractNode{Ts}}
end

"""
BDDForest

A structure to store the information on BDD.

Todo: Get rid of `mutable` (export `totalnodeid` to BDDNodeManager?)
"""

mutable struct BDDForest{Ts}
    totalnodeid::NodeID
    vars::Vector{NodeHeader{Ts}}
    headers::Dict{Ts,NodeHeader{Ts}}
    utable::Dict{Tuple{HeaderID,NodeID,NodeID},AbstractNode{Ts}}
    zero::Terminal{Ts}
    one::Terminal{Ts}
    notop::UniOperator{Ts}
    andop::BinOperator{Ts}
    orop::BinOperator{Ts}
    xorop::BinOperator{Ts}
end

function bdd(::Type{Ts} = Symbol) where Ts
    zero = Terminal{Ts}(0)
    one = Terminal{Ts}(1)
    start_node_id::NodeID = 2
    v = Vector{NodeHeader{Ts}}[]
    h = Dict{Ts,NodeHeader{Ts}}()
    ut = Dict{Tuple{HeaderID,NodeID,NodeID},AbstractNode{Ts}}()
    notop = UniOperator{Ts}(BDDNot(), Dict{NodeID,AbstractNode{Ts}}())
    andop = BinOperator{Ts}(BDDAnd(), Dict{Tuple{NodeID,NodeID},AbstractNode{Ts}}())
    orop = BinOperator{Ts}(BDDOr(), Dict{Tuple{NodeID,NodeID},AbstractNode{Ts}}())
    xorop = BinOperator{Ts}(BDDXor(), Dict{Tuple{NodeID,NodeID},AbstractNode{Ts}}())
    b = BDDForest{Ts}(2, v, h, ut, zero, one, notop, andop, orop, xorop)
end

function get_next_nodeid!(b::BDDForest{Ts}) where Ts
    id = b.totalnodeid
    b.totalnodeid += 1
    id
end

"""
header!

Get a header for a variable on BDD with a label
"""

function header!(b::BDDForest{Ts}, label::Ts)::NodeHeader{Ts} where Ts
    h = get(b.headers, label) do
        h = NodeHeader{Ts}(HeaderID(length(b.vars)), length(b.vars), label)
        push!(b.vars, h)
        b.headers[label] = h
    end
    h
end

"""
var!

Get a node for a variable
"""

function var!(b::BDDForest{Ts}, label::Ts)::AbstractNode{Ts} where Ts
    h = header!(b, label)
    node!(b, h, b.zero, b.one)
end

"""
node!

Create a BDD node
"""

function node!(b::BDDForest{Ts}, h::NodeHeader{Ts}, low::AbstractNode{Ts}, high::AbstractNode{Ts})::AbstractNode{Ts} where Ts
    if low.id == high.id
        return low
    end
    key = (h.id, low.id, high.id)
    get(b.utable, key) do
        nextid = get_next_nodeid!(b)
        b.utable[key] = Node(nextid, h, low, high)
    end
end

"""
not

Return a node of negation for a given node.
"""

function not(b::BDDForest{Ts}, f::AbstractNode{Ts}) where Ts
    uniapply!(b.notop, b, f)
end

"""
and

Return a node of AND for given nodes
"""

function and(b::BDDForest{Ts}, f::Vararg{AbstractNode{Ts}}) where Ts
    ans = b.one
    for i = 1:length(f)
        ans = binapply!(b.andop, b, ans, f[i])
    end
    ans
end

"""
or

Return a node of OR for given nodes
"""

function or(b::BDDForest{Ts}, f::Vararg{AbstractNode{Ts}}) where Ts
    ans = b.zero
    for i = 1:length(f)
        ans = binapply!(b.orop, b, ans, f[i])
    end
    ans
end

"""
xor

Return a node of XOR for given two nodes
"""

function xor(b::BDDForest{Ts}, f::AbstractNode{Ts}, g::AbstractNode{Ts}) where Ts
    binapply!(b.xorop, b, f, g)
end

"""
imp

Return a node of IMP for given two nodes
"""

function imp(b::BDDForest{Ts}, f::AbstractNode{Ts}, g::AbstractNode{Ts}) where Ts
    or(b, not(b, f), g)
end

"""
imp

Return a node of if-then-else for given three nodes
"""

function ite(b::BDDForest{Ts}, f::AbstractNode{Ts}, g::AbstractNode{Ts}, h::AbstractNode{Ts}) where Ts
    or(b, and(b, f, g), and(b, not(b, f), h))
end

"""
uniapply

Apply operation for unioperator
"""

function uniapply!(op::UniOperator{Ts}, b::BDDForest{Ts}, f::AbstractNode{Ts})::AbstractNode{Ts} where Ts
    return _uniapply!(op.op, op, b, f)
end

function _uniapply!(::AbstractOperator, op::UniOperator{Ts}, b::BDDForest{Ts}, f::Node{Ts})::AbstractNode{Ts} where Ts
    get(op.cache, f.id) do
        n0 = _uniapply!(op.op, op, b, f.low)
        n1 = _uniapply!(op.op, op, b, f.high)
        ans = node!(b, f.header, n0, n1)
        op.cache[f.id] = ans
    end
end

function _uniapply!(::BDDNot, op::UniOperator{Ts}, b::BDDForest{Ts}, f::Terminal{Ts})::AbstractNode{Ts} where Ts
    if f == b.one
        b.zero
    else
        b.one
    end
end

"""
binapply

Apply operation for binoperator
"""

function binapply!(op::BinOperator{Ts}, b::BDDForest{Ts}, f::AbstractNode{Ts}, g::AbstractNode{Ts})::AbstractNode{Ts} where Ts
    return _binapply!(op.op, op, b, f, g)
end

function _binapply!(::AbstractOperator, op::BinOperator{Ts}, b::BDDForest{Ts}, f::Node{Ts}, g::Node{Ts})::AbstractNode{Ts} where Ts
    key = (f.id, g.id)
    get(op.cache, key) do
        if f.header.level > g.header.level
            n0 = _binapply!(op.op, op, b, f.low, g)
            n1 = _binapply!(op.op, op, b, f.high, g)
            ans = node!(b, f.header, n0, n1)
        elseif f.header.level < g.header.level
            n0 = _binapply!(op.op, op, b, f, g.low)
            n1 = _binapply!(op.op, op, b, f, g.high)
            ans = node!(b, g.header, n0, n1)
        else
            n0 = _binapply!(op.op, op, b, f.low, g.low)
            n1 = _binapply!(op.op, op, b, f.high, g.high)
            ans = node!(b, f.header, n0, n1)
        end
        op.cache[key] = ans
    end
end

function _binapply!(::AbstractOperator, op::BinOperator{Ts}, b::BDDForest{Ts}, f::Terminal{Ts}, g::Node{Ts})::AbstractNode{Ts} where Ts
    key = (f.id, g.id)
    get(op.cache, key) do
        n0 = _binapply!(op.op, op, b, f, g.low)
        n1 = _binapply!(op.op, op, b, f, g.high)
        op.cache[key] = node!(b, g.header, n0, n1)
    end
end

function _binapply!(::AbstractOperator, op::BinOperator{Ts}, b::BDDForest{Ts}, f::Node{Ts}, g::Terminal{Ts})::AbstractNode{Ts} where Ts
    key = (f.id, g.id)
    get(op.cache, key) do
        n0 = _binapply!(op.op, op, b, f.low, g)
        n1 = _binapply!(op.op, op, b, f.high, g)
        op.cache[key] = node!(b, f.header, n0, n1)
    end
end

## and

function _binapply!(::BDDAnd, op::BinOperator{Ts}, b::BDDForest{Ts}, f::Terminal{Ts}, g::Node{Ts})::AbstractNode{Ts} where Ts
    if f == b.one
        g
    else
        b.zero
    end
end

function _binapply!(::BDDAnd, op::BinOperator{Ts}, b::BDDForest{Ts}, f::Node{Ts}, g::Terminal{Ts})::AbstractNode{Ts} where Ts
    if g == b.one
        f
    else
        b.zero
    end
end

function _binapply!(::BDDAnd, op::BinOperator{Ts}, b::BDDForest{Ts}, f::Terminal{Ts}, g::Terminal{Ts})::AbstractNode{Ts} where Ts
    if f == b.one && g == b.one
        b.one
    else
        b.zero
    end
end

## or

function _binapply!(::BDDOr, op::BinOperator{Ts}, b::BDDForest{Ts}, f::Terminal{Ts}, g::Node{Ts})::AbstractNode{Ts} where Ts
    if f == b.one
        b.one
    else
        g
    end
end

function _binapply!(::BDDOr, op::BinOperator{Ts}, b::BDDForest{Ts}, f::Node{Ts}, g::Terminal{Ts})::AbstractNode{Ts} where Ts
    if g == b.one
        b.one
    else
        f
    end
end

function _binapply!(::BDDOr, op::BinOperator{Ts}, b::BDDForest{Ts}, f::Terminal{Ts}, g::Terminal{Ts})::AbstractNode{Ts} where Ts
    if f == b.zero && g == b.zero
        b.zero
    else
        b.one
    end
end

## xor

function _binapply!(::BDDXor, op::BinOperator{Ts}, b::BDDForest{Ts}, f::Terminal{Ts}, g::Terminal{Ts})::AbstractNode{Ts} where Ts
    if f == g
        b.zero
    else
        b.one
    end
end

"""
todot(forest, f)
Return a string for dot to draw a diagram.
"""

function todot(b::BDDForest{Ts}, f::AbstractNode{Ts}) where Ts
    io = IOBuffer()
    visited = Set{AbstractNode{Ts}}()
    println(io, "digraph { layout=dot; overlap=false; splines=true; node [fontsize=10];")
    _todot!(b, f, visited, io)
    println(io, "}")
    return String(take!(io))
end

function _todot!(b::BDDForest{Ts}, f::Terminal{Ts}, visited::Set{AbstractNode{Ts}}, io::IO)::Nothing where Ts
    if in(f, visited)
        return
    end
    if f == b.zero
        println(io, "\"obj$(f.id)\" [shape = square, label = \"0\"];")
    else
        println(io, "\"obj$(f.id)\" [shape = square, label = \"1\"];")
    end
    push!(visited, f)
    nothing
end

function _todot!(b::BDDForest{Ts}, f::Node{Ts}, visited::Set{AbstractNode{Ts}}, io::IO)::Nothing where Ts
    if in(f, visited)
        return
    end
    println(io, "\"obj$(f.id)\" [shape = circle, label = \"$(f.header.label)\"];")
    _todot!(b, f.low, visited, io)
    _todot!(b, f.high, visited, io)
    println(io, "\"obj$(f.id)\" -> \"obj$(f.low.id)\" [label = \"0\"];")
    println(io, "\"obj$(f.id)\" -> \"obj$(f.high.id)\" [label = \"1\"];")
    push!(visited, f)
    nothing
end

end
