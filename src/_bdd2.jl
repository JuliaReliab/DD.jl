export BDD2

"""
type alias
"""

const UniqueTable2{Ts} = Dict{Tuple{HeaderID,NodeID,NodeID,Bool},AbstractBDDNode{Ts}}
const BinCache2{Ts} = Dict{Tuple{NodeID,Bool,NodeID,Bool},Tuple{AbstractBDDNode{Ts},Bool}}

"""
Node2
"""

struct BDD2Node{Ts} <: AbstractBDDNode{Ts}
    id::NodeID
    header::BDDNodeHeader{Ts}
    low::AbstractBDDNode{Ts}
    high::AbstractBDDNode{Ts}
    neg::Bool
end

"""
BDD2{Ts}

The structure for BDD. This includes all the nodes and caches.
"""

struct BDD2{Ts}
    manager::BDDManager
    headers::Dict{Ts,BDDNodeHeader{Ts}}
    utable::UniqueTable2{Ts}
    zero::BDDTerminal{Ts}
    andcache::BinCache2{Ts}
    orcache::BinCache2{Ts}
    xorcache::BinCache2{Ts}
end

function BDD2(::Type{Ts} = Symbol) where Ts
    manager = BDDManager()
    zero = BDDTerminal{Ts}(nodeid!(manager))
    BDD2{Ts}(
        manager,
        Dict{Ts,BDDNodeHeader{Ts}}(),
        UniqueTable2{Ts}(),
        zero,
        BinCache2{Ts}(),
        BinCache2{Ts}(),
        BinCache2{Ts}()
    )
end

function var(b::BDD2{Ts}, label::Ts)::Tuple{AbstractBDDNode{Ts},Bool} where Ts
    h = get(b.headers, label) do
        h = BDDNodeHeader(headerid!(b.manager), level!(b.manager), label)
        b.headers[label] = h
    end
    _node(b, h, b.zero, false, b.zero, true)
end

function _node(b::BDD2{Ts}, h::BDDNodeHeader{Ts}, low::AbstractBDDNode{Ts}, blow::Bool, high::AbstractBDDNode{Ts}, bhigh::Bool)::Tuple{AbstractBDDNode{Ts},Bool} where Ts
    if blow == bhigh && low.id == high.id
        (low, blow)
    else
        flag = blow != bhigh
        key = (h.id, low.id, high.id, flag)
        node = get(b.utable, key) do
            b.utable[key] = BDD2Node(nodeid!(b.manager), h, low, high, flag)
        end
        (node, blow)
    end
end

### binoperator

function not(b::BDD2{Ts}, f::Tuple{AbstractBDDNode{Ts},Bool}) where Ts
    (f[1], !f[2])
end

function and(b::BDD2{Ts}, f::Vararg{Tuple{AbstractBDDNode{Ts},Bool}}) where Ts
    ans, bans = (b.zero, true)
    for x = f
        ans, bans = _binapply(BDDAnd(), b.andcache, b, ans, bans, x[1], x[2])
    end
    (ans, bans)
end

function or(b::BDD2{Ts}, f::Vararg{Tuple{AbstractBDDNode{Ts},Bool}}) where Ts
    ans, bans = (b.zero, false)
    for x = f
        ans, bans = _binapply(BDDOr(), b.orcache, b, ans, bans, x[1], x[2])
    end
    (ans, bans)
end

function xor(b::BDD2{Ts}, f::Tuple{AbstractBDDNode{Ts},Bool}, g::Tuple{AbstractBDDNode{Ts},Bool}) where Ts
    _binapply(BDDXor(), b.xorcache, b, f, g)
end

function imp(b::BDD2{Ts}, f::Tuple{AbstractBDDNode{Ts},Bool}, g::Tuple{AbstractBDDNode{Ts},Bool}) where Ts
    or(b, bddnot(b, f), g)
end

function ite(b::BDD2{Ts}, f::Tuple{AbstractBDDNode{Ts},Bool}, g::Tuple{AbstractBDDNode{Ts},Bool}, h::Tuple{AbstractBDDNode{Ts},Bool}) where Ts
    or(b, and(b, f, g), and(b, not(b, f), h))
end

### primitive

function getzero(f::BDD2Node{Ts}, bf::Bool) where Ts
    (f.low, bf)
end

function getone(f::BDD2Node{Ts}, bf::Bool) where Ts
    (f.high, bf != f.neg)
end

function _binapply(op::AbstractBDDOperator, cache::BinCache2{Ts}, b::BDD2{Ts}, f::BDD2Node{Ts}, bf::Bool, g::BDD2Node{Ts}, bg::Bool)::Tuple{AbstractBDDNode{Ts},Bool} where Ts
    key = (f.id, bf, g.id, bg)
    get(cache, key) do
        if f.header.level > g.header.level
            n0, bn0 = _binapply(op, cache, b, getzero(f, bf)..., g, bg)
            n1, bn1 = _binapply(op, cache, b, getone(f, bf)..., g, bg)
            ans, bans = _node(b, f.header, n0, bn0, n1, bn1)
        elseif f.header.level < g.header.level
            n0, bn0 = _binapply(op, cache, b, f, bf, getzero(g, bg)...)
            n1, bn1 = _binapply(op, cache, b, f, bf, getone(g, bg)...)
            ans, bans = _node(b, g.header, n0, bn0, n1, bn1)
        else
            n0, bn0 = _binapply(op, cache, b, getzero(f, bf)..., getzero(g, bg)...)
            n1, bn1 = _binapply(op, cache, b, getone(f, bf)..., getone(g, bg)...)
            ans, bans = _node(b, f.header, n0, bn0, n1, bn1)
        end
        cache[key] = (ans, bans)
    end
end

## and

function _binapply(::BDDAnd, ::BinCache2{Ts}, b::BDD2{Ts}, f::BDDTerminal{Ts}, bf::Bool, g::BDD2Node{Ts}, bg::Bool)::Tuple{AbstractBDDNode{Ts},Bool} where Ts
    if bf == true
        (g, bg)
    else
        (b.zero, false)
    end
end

function _binapply(::BDDAnd, ::BinCache2{Ts}, b::BDD2{Ts}, f::BDD2Node{Ts}, bf::Bool, g::BDDTerminal{Ts}, bg::Bool)::Tuple{AbstractBDDNode{Ts},Bool} where Ts
    if bg == true
        (f, bf)
    else
        (b.zero, false)
    end
end

function _binapply(::BDDAnd, ::BinCache2{Ts}, b::BDD2{Ts}, f::BDDTerminal{Ts}, bf::Bool, g::BDDTerminal{Ts}, bg::Bool)::Tuple{AbstractBDDNode{Ts},Bool} where Ts
    if bf == true && bg == true
        (b.zero, true)
    else
        (b.zero, false)
    end
end

## or

function _binapply(::BDDOr, ::BinCache2{Ts}, b::BDD2{Ts}, f::BDDTerminal{Ts}, bf::Bool, g::BDD2Node{Ts}, bg::Bool)::Tuple{AbstractBDDNode{Ts},Bool} where Ts
    if bf == true
        (b.zero, true)
    else
        (g, bg)
    end
end

function _binapply(::BDDOr, ::BinCache2{Ts}, b::BDD2{Ts}, f::BDD2Node{Ts}, bf::Bool, g::BDDTerminal{Ts}, bg::Bool)::Tuple{AbstractBDDNode{Ts},Bool} where Ts
    if bg == true
        (b.zero, true)
    else
        (f, bf)
    end
end

function _binapply(::BDDOr, ::BinCache2{Ts}, b::BDD2{Ts}, f::BDDTerminal{Ts}, bf::Bool, g::BDDTerminal{Ts}, bg::Bool)::Tuple{AbstractBDDNode{Ts},Bool} where Ts
    if bf == false && bg == false
        (b.zero, false)
    else
        (b.zero, true)
    end
end

## xor

function _binapply!(::BDDXor, ::BinCache2{Ts}, b::BDD2{Ts}, f::BDDTerminal{Ts}, bf::Bool, g::BDD2Node{Ts}, bg::Bool)::Tuple{AbstractBDDNode{Ts},Bool} where Ts
    if bf == true
        (g, !bg)
    else
        (g, bg)
    end
end

function _binapply!(::BDDXor, ::BinCache2{Ts}, b::BDD2{Ts}, f::BDD2Node{Ts}, bf::Bool, g::BDDTerminal{Ts}, bg::Bool)::Tuple{AbstractBDDNode{Ts},Bool} where Ts
    if bg == true
        (f, !bf)
    else
        (f, bf)
    end
end

function _binapply!(::BDDXor, ::BinCache2{Ts}, b::BDD2{Ts}, f::BDDTerminal{Ts}, bf::Bool, g::BDDTerminal{Ts}, bg::Bool)::Tuple{AbstractBDDNode{Ts},Bool} where Ts
    if bf == bg
        (b.zero, false)
    else
        (b.zero, true)
    end
end

##

# function fteval(b::BDD{Ts}, f::Tuple{AbstractNode{Ts},Bool}, env::Dict{Ts,Tx})::Tx where {Ts,Tx}
#     cache = Dict{Tuple{UInt,Bool},Tx}()
#     _fteval(b, f, env, cache)
# end

# function _fteval(b::BDD{Ts}, f::Tuple{Node{Ts},Bool}, env::Dict{Ts,Tx}, cache::Dict{Tuple{UInt,Bool},Tx})::Tx where {Ts,Tx}
#     get(cache, (f[1].id, f[2])) do
#         p = env[f[1].header.label]
#         fprob = (1-p) * _fteval(b, getzero(f), env, cache) + p * _fteval(b, getone(f), env, cache)
#         cache[(f[1].id,!f[2])] = 1 - fprob
#         cache[(f[1].id,f[2])] = fprob
#     end
# end

# function _fteval(b::BDD{Ts}, f::Tuple{Terminal{Ts},Bool}, env::Dict{Ts,Tx}, cache::Dict{Tuple{UInt,Bool},Tx})::Tx where {Ts,Tx}
#     (f[2] == false) ? Tx(0) : Tx(1)
# end

# ##

# mutable struct MinPath
#     len::Int
#     set::Vector{Vector{Bool}}
# end

# function ftmcs(b::BDD{Ts}, f::Tuple{AbstractNode{Ts},Bool}) where Ts
#     result = Vector{Ts}[]
#     r = f
#     while r != (b.zero, false)
#         f, s = _ftmcs(b, r)
#         append!(result, s)
#         r = bddnot(b, bddimp(b, r, f))
#     end
#     result
# end

# function _ftmcs(b::BDD{Ts}, f::Tuple{AbstractNode{Ts},Bool}) where Ts
#     vars = Dict([x.level => var!(b, x.label) for (k,x) = b.headers])
#     path = [false for i = 1:Int(b.totalvarid)]
#     s = MinPath(Int(b.totalvarid), Vector{Bool}[])
#     _ftmcs(b, f, path, s)
#     result = (b.zero, false)
#     result2 = Vector{Ts}[]
#     for x = s.set
#         tmp = (b.zero, true)
#         tmp2 = Ts[]
#         for i = 1:length(x)
#             if x[i] == true
#                 tmp = bddand(b, tmp, vars[i])
#                 push!(tmp2, vars[i][1].header.label)
#             end
#         end
#         result = bddor(b, result, tmp)
#         push!(result2, tmp2)
#     end
#     return result, result2
# end

# function _ftmcs(b::BDD{Ts}, f::Tuple{Node{Ts},Bool}, path::Vector{Bool}, s::MinPath) where Ts
#     if s.len < sum(path)
#         return
#     end
#     path[f[1].header.level] = false
#     _ftmcs(b, getzero(f), path, s)
#     path[f[1].header.level] = true
#     _ftmcs(b, getone(f), path, s)
#     path[f[1].header.level] = false
#     nothing
# end

# function _ftmcs(b::BDD{Ts}, f::Tuple{Terminal{Ts},Bool}, path::Vector{Bool}, s::MinPath) where Ts
#     if f[2] == true
#         if s.len > sum(path)
#             s.len = sum(path)
#             s.set = [copy(path)]
#         elseif s.len == sum(path)
#             push!(s.set, copy(path))
#         end
#     end
#     nothing
# end

##

function todot(b::BDD2{Ts}, f::Tuple{AbstractBDDNode{Ts},Bool}) where Ts
    io = IOBuffer()
    visited = Set{AbstractBDDNode{Ts}}()
    println(io, "digraph { layout=dot; overlap=false; splines=true; node [fontsize=10];")
    _todot!(b, f[1], visited, io)
    println(io, "}")
    return String(take!(io))
end

function _todot!(b::BDD2{Ts}, f::BDDTerminal{Ts}, visited::Set{AbstractBDDNode{Ts}}, io::IO)::Nothing where Ts
    if in(f, visited)
        return
    end
    println(io, "\"obj$(f.id)\" [shape = square, label = \"0\"];")
    push!(visited, f)
    nothing
end

function _todot!(b::BDD2{Ts}, f::BDD2Node{Ts}, visited::Set{AbstractBDDNode{Ts}}, io::IO)::Nothing where Ts
    if in(f, visited)
        return
    end
    
    println(io, "\"obj$(f.id)\" [shape = circle, label = \"$(f.header.label)\"];")
    _todot!(b, f.low, visited, io)
    println(io, "\"obj$(f.id)\" -> \"obj$(f.low.id)\" [label = \"0\"];")
    _todot!(b, f.high, visited, io)
    if f.neg == false
        println(io, "\"obj$(f.id)\" -> \"obj$(f.high.id)\" [label = \"1\"];")
    else
        println(io, "\"obj$(f.id)\" -> \"obj$(f.high.id)\" [label = \"1\", arrowhead = odot];")
    end
    push!(visited, f)
    nothing
end
