"""
EVMDD Module
"""

module EVMDD

import ..MDD

export AbstractNode
export AbstractNonTerminalNode
export AbstractTerminalNode
export NodeID
export Level
export DomainValue

export evmdd
export vars
export forest

export id
export level
export label
export domain
export node!
export value!

export iszero
export isone

export defvar!

export mdd2evmdd

export todot

abstract type AbstractNode end
abstract type AbstractNonTerminalNode <: AbstractNode end
abstract type AbstractEdge <: AbstractNode end
abstract type AbstractTerminalNode <: AbstractNode end

const NodeID = UInt
const Level = UInt
const DomainValue = Int

# """
#     AbstractOperator
#     AbstractUnaryOperator <: AbstractOperator
#     AbstractBinaryOperator <: AbstractOperator
#     NotOperator <: AbstractUnaryOperator
#     AndOperator <: AbstractBinaryOperator
#     OrOperator <: AbstractBinaryOperator
#     XorOperator <: AbstractBinaryOperator
#     EqOperator <: AbstractBinaryOperator

# Types for operations.
# - NotOperator: Logical not operation
# - AndOperator: Logical and operation
# - OrOperator: Logical or operation
# - XorOperator: Logical xor operation
# - EqOperator: Logical eq operation
# """
# abstract type AbstractOperator end
# abstract type AbstractUnaryOperator <: AbstractOperator end
# abstract type AbstractBinaryOperator <: AbstractOperator end
# struct MDDMin <: AbstractBinaryOperator end
# struct MDDMax <: AbstractBinaryOperator end
# struct MDDPlus <: AbstractBinaryOperator end
# struct MDDMinus <: AbstractBinaryOperator end
# struct MDDMul <: AbstractBinaryOperator end
# struct MDDLte <: AbstractBinaryOperator end
# struct MDDLt <: AbstractBinaryOperator end
# struct MDDGte <: AbstractBinaryOperator end
# struct MDDGt <: AbstractBinaryOperator end
# struct MDDEq <: AbstractBinaryOperator end
# struct MDDNeq <: AbstractBinaryOperator end
# struct MDDAnd <: AbstractBinaryOperator end
# struct MDDOr <: AbstractBinaryOperator end
# struct MDDNot <: AbstractUnaryOperator end
# struct MDDIf <: AbstractBinaryOperator end
# struct MDDElse <: AbstractBinaryOperator end
# struct MDDUnion <: AbstractBinaryOperator end

# """
#     AbstractPolicy
#     FullyReduced <: AbstractPolicy
#     QuasiReduced <: AbstractPolicy

# The types for reduction policy in DD.
# - FullyReduced: the node is reduced if all the edges are directed to the same node.
# - QuasiReduced: the node is not reduced even if all the edges are directed to the same node.
# """
# abstract type AbstractPolicy end
# struct FullyReduced <: AbstractPolicy end
# struct QuasiReduced <: AbstractPolicy end

"""
    NodeManager

A mutable structure to issue the unique number as ID.
"""
mutable struct NodeManager
    nextid::NodeID
end

"""
    _get_next!(mgr::NodeManager)::NodeID

Issue an ID.
"""
function _get_next!(mgr::NodeManager)::NodeID
    id = mgr.nextid
    mgr.nextid += 1
    id
end

"""
    NodeHeader

A mutable structure indicating the information for nodes in the same level.
- id: Header ID
- level: Level of node. The level of terminal node is 0. 
- label: A symbol to represent the variable
- domain: A vector as the domain of variable
- index: A dictionary to provide the index for a given value.
"""
mutable struct NodeHeader
    id::NodeID
    level::Level
    label::Symbol
    domain::Vector{DomainValue}
    index::Dict{DomainValue,Int}

    # function NodeHeader(level::Level, domain::DomainValue)
    #     new(NodeID(level), level, Symbol(level), [i for i = 1:domain])
    # end

    function NodeHeader(id::NodeID, level::Level, label::Symbol, domain::Vector{DomainValue})
        new(id, level, label, domain, Dict([x => i for (i,x) = enumerate(domain)]...))
    end
end

"""
    Forest

A mutable structure to store the information on DD. The fields are
- mgr: NodeManager to issue IDs of nodes
- hmgr: NodeManager to issue IDs of headers
- headers: A dictionary of the pair of Symbol and NodeHeader
- utable: Unique table to identify the tuple (header id, low node id, high node id)
- zero: A terminal node indicating logical zero
- one: A terminal node indicating logical one
- undet: A terminal node indicating logical undermined value
- cache: A cache for operations
"""
mutable struct Forest
    mgr::NodeManager
    hmgr::NodeManager
    edgemgr::NodeManager
    headers::Dict{Symbol,NodeHeader}
    utable::Dict{Tuple{NodeID,Vector{NodeID}},AbstractNode}
    etable::Dict{Tuple{Any,NodeID},AbstractEdge}
    zero::AbstractTerminalNode
    one::AbstractTerminalNode

    function Forest()
        b = new()
        b.mgr = NodeManager(0)
        b.hmgr = NodeManager(0)
        b.edgemgr = NodeManager(0)
        b.headers = Dict{Symbol,NodeHeader}()
        b.utable = Dict{Tuple{NodeID,Vector{NodeID}},AbstractNode}()
        b.etable = Dict{Tuple{Any,NodeID},AbstractEdge}()
        b.zero = ZeroTerminal(b, _get_next!(b.mgr))
        b.one = OneTerminal(b, _get_next!(b.mgr))
        b
    end
end

Base.show(io::IO, b::Forest) = Base.show(io, objectid(b))
evmdd() = Forest()
vars(b::Forest) = b.headers

mutable struct Node <: AbstractNonTerminalNode
    b::Forest
    id::NodeID
    header::NodeHeader
    edges::Vector{AbstractEdge}
end

mutable struct Edge <: AbstractEdge
    b::Forest
    id::NodeID
    val
    node::AbstractNode
end

struct OneTerminal <: AbstractTerminalNode
    b::Forest
    id::NodeID
end

struct ZeroTerminal <: AbstractTerminalNode
    b::Forest
    id::NodeID
end

Base.show(io::IO, n::AbstractNode) = Base.show(io, "node$(n.id)")
Base.show(io::IO, n::AbstractEdge) = Base.show(io, "edge$(n.id)")

get_edges(x::AbstractNonTerminalNode) = x.edges
get_node(x::AbstractEdge) = x.node

id(x::NodeHeader) = x.id
id(x::AbstractNode) = x.id
id(x::AbstractEdge) = x.id

level(x::NodeHeader) = x.level
level(x::AbstractNonTerminalNode) = x.header.level
level(::AbstractTerminalNode) = Level(0)

label(x::NodeHeader) = x.label
label(x::AbstractNonTerminalNode) = x.header.label
# label(x::AbstractTerminalNode) = Symbol(x.value)

domain(x::NodeHeader) = x.domain
domain(x::AbstractNonTerminalNode) = x.header.domain

function edge!(b::Forest, val, node::AbstractNode)
    key = (val, node.id)
    get!(b.etable, key) do
        id = _get_next!(b.edgemgr)
        Edge(b, id, val, node)
    end
end

function node!(b::Forest, h::NodeHeader, edges::Vector{AbstractEdge})
    _node!(b, h, edges)
end

function _node!(b::Forest, h::NodeHeader, edges::Vector{AbstractEdge})
    if _issame(edges)
        return get_node(edges[1])
    end
    key = (h.id, [x.id for x = edges])
    get!(b.utable, key) do
        id = _get_next!(b.mgr)
        Node(b, id, h, edges)
    end
end

function _issame(edges::Vector{AbstractEdge})
    # assume length(nodes) >= 2
    tmp = edges[1]
    for x = edges[2:end]
        if tmp.id != x.id
            return false
        end
    end
    return true
end

function defvar!(b::Forest, name::Symbol, level::Int, domain::AbstractVector{DomainValue})
    h = NodeHeader(_get_next!(b.hmgr), Level(level), name, collect(domain))
    b.headers[name] = h
end

function forest(f::AbstractNode)
    f.b
end

Base.isone(x::AbstractNonTerminalNode) = false
Base.isone(x::OneTerminal) = true
Base.isone(x::ZeroTerminal) = false

Base.iszero(x::AbstractNonTerminalNode) = false
Base.iszero(x::OneTerminal) = false
Base.iszero(x::ZeroTerminal) = true

# forest(f::AbstractNode) = f.b

todot(f::AbstractNode) = todot(forest(f), f)
todot(f::AbstractEdge) = todot(forest(f), f)

function todot(b::Forest, f::AbstractNode)
    io = IOBuffer()
    visited = Set{NodeID}()
    println(io, "digraph { layout=dot; overlap=false; splines=true; node [fontsize=10];")
    _todot!(b, f, visited, io)
    println(io, "}")
    String(take!(io))
end

function todot(b::Forest, f::AbstractEdge)
    io = IOBuffer()
    visited = Set{NodeID}()
    println(io, "digraph { layout=dot; overlap=false; splines=true; node [fontsize=10];")
    println(io, "\"objroot\" [shape = circle, label = \"\"];")
    println(io, "\"objroot\" -> \"obj$(f.node.id)\" [label = \"($(f.val))\"];")
    _todot!(b, f.node, visited, io)
    println(io, "}")
    String(take!(io))
end

function _todot!(b::Forest, f::OneTerminal, visited::Set{NodeID}, io::IO)
    if in(f.id, visited)
        return
    end
    println(io, "\"obj$(f.id)\" [shape = square, label = \"1\"];")
    push!(visited, f.id)
    nothing
end

function _todot!(b::Forest, f::ZeroTerminal, visited::Set{NodeID}, io::IO)
    if in(f.id, visited)
        return
    end
    println(io, "\"obj$(f.id)\" [shape = square, label = \"0\"];")
    push!(visited, f.id)
    nothing
end

function _todot!(b::Forest, f::Node, visited::Set{NodeID}, io::IO)
    if in(f.id, visited)
        return
    end
    println(io, "\"obj$(f.id)\" [shape = circle, label = \"$(f.header.label)\"];")
    for (i,x) = enumerate(f.header.domain)
        if f.edges[i].node.id != b.zero.id
            _todot!(b, f.edges[i].node, visited, io)
            println(io, "\"obj$(f.id)\" -> \"obj$(f.edges[i].node.id)\" [label = \"($(x),$(f.edges[i].val))\"];")
        end
    end
    push!(visited, f.id)
    nothing
end

function Base.size(f::AbstractNode)
    b = forest(f)
    visited = Set{NodeID}()
    edges = _size!(b, f, visited)
    (length(visited), edges)
end

function Base.size(f::AbstractEdge)
    (nn, ne) = Base.size(f.node)
    (nn, ne+1)
end

function _size!(b::Forest, f::AbstractTerminalNode, visited::Set{NodeID})
    if in(f.id, visited)
        return 0
    end
    push!(visited, f.id)
    return 0
end

function _size!(b::Forest, f::Node, visited::Set{NodeID})
    if in(f.id, visited)
        return 0
    end
    tmp = 0
    for (i,x) = enumerate(f.header.domain)
        if f.edges[i].node.id != b.zero.id
            tmp += _size!(b, f.edges[i].node, visited)
            tmp += 1
        end
    end
    push!(visited, f.id)
    return tmp
end

# function defvar!(b::Forest, name::Symbol, level::Int, domain::AbstractVector{DomainValue})
#     h = NodeHeader(_get_next!(b.hmgr), Level(level), name, collect(domain))
#     b.headers[name] = h
# end

function defvar!(b::Forest, name::Symbol, level::Level, domain::AbstractVector{DomainValue})
    h = NodeHeader(_get_next!(b.hmgr), level, name, collect(domain))
    b.headers[name] = h
end

function mdd2evmdd(x::MDD.AbstractNode)
    evmddforest = Forest()
    mdd2evmdd(evmddforest, x)
end

function mdd2evmdd(evmddforest::Forest, x::MDD.AbstractNode)
    b = MDD.forest(x)
    cache = Dict()
    for (name,h) = b.headers
        defvar!(evmddforest, name, h.level, h.domain)
    end
    (v, n) = _mdd2evpmdd(b, x, evmddforest, cache)
    edge!(evmddforest, v, n)
end

function _mdd2evpmdd(b::MDD.Forest, f::MDD.AbstractTerminalNode, evmddforest::Forest, cache)
    get!(cache, f.id) do
        (f.value, evmddforest.one)
    end
end

function _mdd2evpmdd(b::MDD.Forest, f::MDD.AbstractTerminalNode{Nothing}, evmddforest::Forest, cache)
    get!(cache, f.id) do
        (f.value, evmddforest.zero)
    end
end

function _mdd2evpmdd(b::MDD.Forest, f::MDD.AbstractNonTerminalNode, evmddforest::Forest, cache)
    get!(cache, f.id) do
        tmp = []
        tmpv = []
        for (i,x) = enumerate(f.header.domain)
            (v, n) = _mdd2evpmdd(b, f.nodes[i], evmddforest, cache)
            push!(tmp, (v, n))
            if !isnothing(v)
                push!(tmpv, v)
            end
        end
        minv = minimum(tmpv)
        edges = AbstractEdge[]
        for (v, n) = tmp
            if !isnothing(v)
                push!(edges, edge!(evmddforest, v-minv, n))
            else
                push!(edges, edge!(evmddforest, v, n))
            end
        end
        (minv, node!(evmddforest, evmddforest.headers[f.header.label], edges))
    end
end

end
