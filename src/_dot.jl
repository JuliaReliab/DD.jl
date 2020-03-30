
export todot, ddview

"""
dot for DD
"""

using PyCall
using Conda
Conda.add("python-graphviz", channel="conda-forge")
Conda.add("pydotplus", channel="conda-forge")

const PydotPlus = PyNULL()

function __init__()
    copy!(PydotPlus, pyimport_conda("pydotplus", "pydotplus"))
end

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

"""
ddview(forest, f)

Draw a diagram in Jupyter environemnt.
"""

function ddview(forest::AbstractDDForest{Tv,Ti,Tl},
        f::DDVariable{Tv,Ti,N})::Nothing where {Tv,Ti,Tl,N}
    bdd = PydotPlus.graph_from_dot_data(todot(forest, f))
    bdd.progs = Dict("dot" => "$(ENV["HOME"])/.julia/conda/3/bin/dot")
    display("image/png", Vector{UInt8}(bdd.create_png()))
end

