export reversetree
export AbstractEdge
export EdgeRoot
export Edge0
export Edge1

"""
     AbstractEdge
     EdgeRoot <: AbstractEdge
     Edge0 <: AbstractEdge
     Edge1 <: AbstractEdge

An abstract class for edge from child to parent. Egde0 and Edge1 indicate 0-edge and 1-edge respectively.
EdgeRoot is the edge to the root node.
"""
abstract type AbstractEdge end

struct EdgeRoot <: AbstractEdge end

struct Edge0 <: AbstractEdge
    parent::AbstractNode
end

struct Edge1 <: AbstractEdge
    parent::AbstractNode
end

"""
    reversetree(f::AbstractNode)

Make a dictionary consisting of edges from child to its parents in BDD. The key of dictionary is NodeID and
the value of dictionary is a vector of edges. The complexity is proportinal to the number of edges.
"""
function reversetree(f::AbstractNode)
    result = Dict{NodeID,Vector{AbstractEdge}}()
    visited = Set{NodeID}()
    _makegraph(f, EdgeRoot(), result, visited)
    result
end    

function _makegraph(f::AbstractNonTerminalNode, parent::AbstractEdge, res::Dict{NodeID,Vector{AbstractEdge}}, visited::Set{NodeID})
    parents = get(res, id(f), AbstractEdge[])
    push!(parents, parent)
    res[id(f)] = parents
    if !in(id(f), visited)
        _makegraph(get_zero(f), Edge0(f), res, visited)
        _makegraph(get_one(f), Edge1(f), res, visited)
        push!(visited, id(f))
    end
end

function _makegraph(f::AbstractTerminalNode, parent::AbstractEdge, res::Dict{NodeID,Vector{AbstractEdge}}, visited::Set{NodeID})
    parents = get(res, id(f), AbstractEdge[])
    push!(parents, parent)
    res[id(f)] = parents
end
