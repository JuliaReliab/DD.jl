export BDD, var, not, and, or, xor, imp, ite, todot

"""
AbstractBDDNode{Ts}

An abstract node for BDD. The parameter Ts represents a type for a symbol of variable.
Ts is usually Symbol.
"""

abstract type AbstractBDDNode{Ts} end

"""
type alias
"""

const HeaderID = UInt
const NodeID = UInt
const UniqueTable{Ts} = Dict{Tuple{HeaderID,NodeID,NodeID},AbstractBDDNode{Ts}}
const UniCache{Ts} = Dict{NodeID,AbstractBDDNode{Ts}}
const BinCache{Ts} = Dict{Tuple{NodeID,NodeID},AbstractBDDNode{Ts}}

"""
BDDNodeHeader{Ts}

The structure is to store the information on BDD node.
"""

struct BDDNodeHeader{Ts}
    id::HeaderID
    level::Int
    label::Ts
end

struct BDDNode{Ts} <: AbstractBDDNode{Ts}
    id::NodeID
    header::BDDNodeHeader{Ts}
    low::AbstractBDDNode{Ts}
    high::AbstractBDDNode{Ts}
end

struct BDDTerminal{Ts} <: AbstractBDDNode{Ts}
    id::NodeID
end

abstract type AbstractBDDOperator end

struct BDDNot <: AbstractBDDOperator end
struct BDDAnd <: AbstractBDDOperator end
struct BDDOr <: AbstractBDDOperator end
struct BDDXor <: AbstractBDDOperator end

"""
BDDManager

The structure to issue the NodeID,
"""

mutable struct BDDManager
    nodeid::NodeID
    varid::HeaderID
    maxlevel::Int
end

function BDDManager()
    BDDManager(0, 0, 0)
end

function headerid!(m::BDDManager)
    id = m.varid
    m.varid += 1
    id
end

function level!(m::BDDManager)
    m.maxlevel += 1
end

function nodeid!(m::BDDManager)
    id = m.nodeid
    m.nodeid += 1
    id
end


"""
BDD{Ts}

The structure for BDD. This includes all the nodes and caches.
"""

struct BDD{Ts}
    manager::BDDManager
    headers::Dict{Ts,BDDNodeHeader{Ts}}
    utable::UniqueTable{Ts}
    zero::BDDTerminal{Ts}
    one::BDDTerminal{Ts}
    notcache::UniCache{Ts}
    andcache::BinCache{Ts}
    orcache::BinCache{Ts}
    xorcache::BinCache{Ts}
end

import Base

function Base.show(io::IO, n::AbstractBDDNode{Ts}) where Ts
    Base.show(io, "node$(n.id)")
end

function BDD(::Type{Ts} = Symbol) where Ts
    manager = BDDManager()
    zero = BDDTerminal{Ts}(nodeid!(manager))
    one = BDDTerminal{Ts}(nodeid!(manager))
    BDD{Ts}(
        manager,
        Dict{Ts,BDDNodeHeader{Ts}}(),
        UniqueTable{Ts}(),
        zero,
        one,
        UniCache{Ts}(),
        BinCache{Ts}(),
        BinCache{Ts}(),
        BinCache{Ts}()
    )
end

function var(b::BDD{Ts}, label::Ts)::AbstractBDDNode{Ts} where Ts
    h = get(b.headers, label) do
        h = BDDNodeHeader(headerid!(b.manager), level!(b.manager), label)
        b.headers[label] = h
    end
    _node(b, h, b.zero, b.one)
end

function _node(b::BDD{Ts}, h::BDDNodeHeader{Ts}, low::AbstractBDDNode{Ts}, high::AbstractBDDNode{Ts})::AbstractBDDNode{Ts} where Ts
    if low.id == high.id
        return low
    end
    key = (h.id, low.id, high.id)
    get(b.utable, key) do
        b.utable[key] = BDDNode(nodeid!(b.manager), h, low, high)
    end
end

### uni

function not(b::BDD{Ts}, f::AbstractBDDNode{Ts}) where Ts
    _uniapply(BDDNot(), b.notcache, b, f)
end

### primitive

function _uniapply(op::AbstractBDDOperator, cache::UniCache{Ts}, b::BDD{Ts}, f::BDDNode{Ts})::AbstractBDDNode{Ts} where Ts
    get(cache, f.id) do
        n0 = _uniapply(op, cache, b, f.low)
        n1 = _uniapply(op, cache, b, f.high)
        ans = _node(b, f.header, n0, n1)
        cache[f.id] = ans
    end
end

function _uniapply(::BDDNot, ::UniCache{Ts}, b::BDD{Ts}, f::BDDTerminal{Ts})::AbstractBDDNode{Ts} where Ts
    if f == b.one
        b.zero
    else
        b.one
    end
end

### binoperator

function and(b::BDD{Ts}, f::Vararg{AbstractBDDNode{Ts}}) where Ts
    ans = b.one
    for x = f
        ans = _binapply(BDDAnd(), b.andcache, b, ans, x)
    end
    ans
end

function or(b::BDD{Ts}, f::Vararg{AbstractBDDNode{Ts}}) where Ts
    ans = b.zero
    for x = f
        ans = _binapply(BDDOr(), b.orcache, b, ans, x)
    end
    ans
end

function xor(b::BDD{Ts}, f::AbstractBDDNode{Ts}, g::AbstractBDDNode{Ts}) where Ts
    _binapply(BDDXor(), b.xorcache, b, f, g)
end

function imp(b::BDD{Ts}, f::AbstractBDDNode{Ts}, g::AbstractBDDNode{Ts}) where Ts
    or(b, not(b, f), g)
end

function ite(b::BDD{Ts}, f::AbstractBDDNode{Ts}, g::AbstractBDDNode{Ts}, h::AbstractBDDNode{Ts}) where Ts
    or(b, and(b, f, g), and(b, not(b, f), h))
end

### primitive

function _binapply(op::AbstractBDDOperator, cache::BinCache{Ts}, b::BDD{Ts}, f::BDDNode{Ts}, g::BDDNode{Ts})::AbstractBDDNode{Ts} where Ts
    key = (f.id, g.id)
    get(cache, key) do
        if f.header.level > g.header.level
            n0 = _binapply(op, cache, b, f.low, g)
            n1 = _binapply(op, cache, b, f.high, g)
            ans = _node(b, f.header, n0, n1)
        elseif f.header.level < g.header.level
            n0 = _binapply(op, cache, b, f, g.low)
            n1 = _binapply(op, cache, b, f, g.high)
            ans = _node(b, g.header, n0, n1)
        else
            n0 = _binapply(op, cache, b, f.low, g.low)
            n1 = _binapply(op, cache, b, f.high, g.high)
            ans = _node(b, f.header, n0, n1)
        end
        cache[key] = ans
    end
end

function _binapply(op::AbstractBDDOperator, cache::BinCache{Ts}, b::BDD{Ts}, f::BDDTerminal{Ts}, g::BDDNode{Ts})::AbstractBDDNode{Ts} where Ts
    key = (f.id, g.id)
    get(cache, key) do
        n0 = _binapply(op, cache, b, f, g.low)
        n1 = _binapply(op, cache, b, f, g.high)
        cache[key] = _node(b, g.header, n0, n1)
    end
end

function _binapply(op::AbstractBDDOperator, cache::BinCache{Ts}, b::BDD{Ts}, f::BDDNode{Ts}, g::BDDTerminal{Ts})::AbstractBDDNode{Ts} where Ts
    key = (f.id, g.id)
    get(cache, key) do
        n0 = _binapply(op, cache, b, f.low, g)
        n1 = _binapply(op, cache, b, f.high, g)
        cache[key] = _node(b, f.header, n0, n1)
    end
end

## and

function _binapply(::BDDAnd, ::BinCache{Ts}, b::BDD{Ts}, f::BDDTerminal{Ts}, g::BDDNode{Ts})::AbstractBDDNode{Ts} where Ts
    if f == b.one
        g
    else
        b.zero
    end
end

function _binapply(::BDDAnd, ::BinCache{Ts}, b::BDD{Ts}, f::BDDNode{Ts}, g::BDDTerminal{Ts})::AbstractBDDNode{Ts} where Ts
    if g == b.one
        f
    else
        b.zero
    end
end

function _binapply(::BDDAnd, ::BinCache{Ts}, b::BDD{Ts}, f::BDDTerminal{Ts}, g::BDDTerminal{Ts})::AbstractBDDNode{Ts} where Ts
    if f == b.one && g == b.one
        b.one
    else
        b.zero
    end
end

## or

function _binapply(::BDDOr, ::BinCache{Ts}, b::BDD{Ts}, f::BDDTerminal{Ts}, g::BDDNode{Ts})::AbstractBDDNode{Ts} where Ts
    if f == b.one
        b.one
    else
        g
    end
end

function _binapply(::BDDOr, ::BinCache{Ts}, b::BDD{Ts}, f::BDDNode{Ts}, g::BDDTerminal{Ts})::AbstractBDDNode{Ts} where Ts
    if g == b.one
        b.one
    else
        f
    end
end

function _binapply(::BDDOr, ::BinCache{Ts}, b::BDD{Ts}, f::BDDTerminal{Ts}, g::BDDTerminal{Ts})::AbstractBDDNode{Ts} where Ts
    if f == b.zero && g == b.zero
        b.zero
    else
        b.one
    end
end

## xor

function _binapply(::BDDXor, ::BinCache{Ts}, b::BDD{Ts}, f::BDDTerminal{Ts}, g::BDDTerminal{Ts})::AbstractBDDNode{Ts} where Ts
    if f == g
        b.zero
    else
        b.one
    end
end

##

# function fteval(b::BDD, f::AbstractBDDNode{Ts}, env::Dict{Ts,Tx})::Tx where {Ts,Tx}
#     cache = Dict{UInt,Tx}()
#     _fteval(b, f, env, cache)
# end

# function _fteval(b::BDD, f::Node{Ts}, env::Dict{Ts,Tx}, cache::Dict{UInt,Tx})::Tx where {Ts,Tx}
#     get(cache, f.id) do
#         p = env[f.header.label]
#         fprob = (1-p) * _fteval(b, f.low, env, cache) + p * _fteval(b, f.high, env, cache)
#         cache[f.id] = fprob
#     end
# end

# function _fteval(b::BDD, f::Terminal{Ts}, env::Dict{Ts,Tx}, cache::Dict{UInt,Tx})::Tx where {Ts,Tx}
#     (f == b.zero) ? Tx(0) : Tx(1)
# end

# ##

# mutable struct MinPath
#     len::Int
#     set::Vector{Vector{Bool}}
# end

# function ftmcs(b::BDD, f::AbstractNode{Ts}) where Ts
#     result = Vector{Ts}[]
#     r = f
#     while r != b.zero
#         f, s = _ftmcs(b, r)
#         append!(result, s)
#         r = bddnot(b, bddimp(b, r, f))
#     end
#     result
# end

# function _ftmcs(b::BDD, f::AbstractNode{Ts}) where Ts
#     vars = Dict([x.level => var!(b, x.label) for (k,x) = b.headers])
#     path = [false for i = 1:Int(b.totalvarid)]
#     s = MinPath(Int(b.totalvarid), Vector{Bool}[])
#     _ftmcs(b, f, path, s)
#     result = b.zero
#     result2 = Vector{Ts}[]
#     for x = s.set
#         tmp = b.one
#         tmp2 = Ts[]
#         for i = 1:length(x)
#             if x[i] == true
#                 tmp = bddand(b, tmp, vars[i])
#                 push!(tmp2, vars[i].header.label)
#             end
#         end
#         result = bddor(b, result, tmp)
#         push!(result2, tmp2)
#     end
#     return result, result2
# end

# function _ftmcs(b::BDD, f::Node{Ts}, path::Vector{Bool}, s::MinPath) where Ts
#     if s.len < sum(path)
#         return
#     end
#     path[f.header.level] = false
#     _ftmcs(b, f.low, path, s)
#     path[f.header.level] = true
#     _ftmcs(b, f.high, path, s)
#     path[f.header.level] = false
#     nothing
# end

# function _ftmcs(b::BDD, f::Terminal{Ts}, path::Vector{Bool}, s::MinPath) where Ts
#     if f == b.one
#         if s.len > sum(path)
#             s.len = sum(path)
#             s.set = [copy(path)]
#         elseif s.len == sum(path)
#             push!(s.set, copy(path))
#         end
#     end
#     nothing
# end

"""
todot(forest, f)

Return a string for dot to draw a diagram.
"""

function todot(b::BDD{Ts}, f::AbstractBDDNode{Ts}) where Ts
    io = IOBuffer()
    visited = Set{AbstractBDDNode{Ts}}()
    println(io, "digraph { layout=dot; overlap=false; splines=true; node [fontsize=10];")
    _todot!(b, f, visited, io)
    println(io, "}")
    return String(take!(io))
end

function _todot!(b::BDD{Ts}, f::BDDTerminal{Ts}, visited::Set{AbstractBDDNode{Ts}}, io::IO)::Nothing where Ts
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

function _todot!(b::BDD{Ts}, f::BDDNode{Ts}, visited::Set{AbstractBDDNode{Ts}}, io::IO)::Nothing where Ts
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

