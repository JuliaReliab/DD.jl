
export todot

"""
dot for DD
"""

"""
todot(forest, f)

Return a string for dot to draw a diagram.
"""

function todot(forest::AbstractDDForest{Tv,Ti,Tl},
        f::AbstractDDNode{Tv,Ti}) where {Tv,Ti,Tl}
    io = IOBuffer()
    visited = Set{AbstractDDNode{Tv,Ti}}()
    println(io, "digraph { layout=dot; overlap=false; splines=true; node [fontsize=10];")
    _todot!(forest, f, visited, io)
    println(io, "}")
    return String(take!(io))
end

function _todot!(forest::AbstractDDForest{Tv,Ti,Tl},
        f::DDValue{Tv,Ti}, visited::Set{AbstractDDNode{Tv,Ti}}, io::IO)::Nothing where {Tv,Ti,Tl}
    if in(f, visited)
        return
    end
    println(io, "\"obj$(objectid(f))\" [shape = square, label = \"$(f.val)\"];")
    push!(visited, f)
    nothing
end

function _todot!(forest::AbstractDDForest{Tv,Ti,Tl},
        f::DDVariable{Tv,Ti}, visited::Set{AbstractDDNode{Tv,Ti}}, io::IO)::Nothing where {Tv,Ti,Tl}
    if in(f, visited)
        return
    end
    println(io, "\"obj$(objectid(f))\" [shape = circle, label = \"$(f.label)\"];")
    for (i,x) = enumerate(f.nodes)
        _todot!(forest, x, visited, io)
        d = forest.vars[f.label][2]
        println(io, "\"obj$(objectid(f))\" -> \"obj$(objectid(x))\" [label = \"$(d[i])\"];")
    end
    push!(visited, f)
    nothing
end

