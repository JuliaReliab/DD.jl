module FTTest

using DD.BDD
using Test

@testset "FT1" begin
    function prob(f::AbstractNonTerminalNode, pb)
        x = label(f)
        p = pb[x]
        pbar = 1.0 - p
    
        b0 = prob(get_zero(f), pb)
        b1 = prob(get_one(f), pb)
    
        pbar * b0 + p * b1
    end
    
    function prob(f::AbstractTerminalNode, pb)
        if iszero(f)
            0.0
        else
            1.0
        end
    end
    
    b = bdd()
    defvar!(b, :x, 1)
    defvar!(b, :y, 2)
    defvar!(b, :z, 3)
    x = var!(b, :x)
    y = var!(b, :y)
    z = var!(b, :z)

    f = (x + y) * z
    println(todot(f))
    pb = Dict(:x=>0.9, :y=>0.9, :z=>0.9)
    @test prob(f, pb) == 0.9 * (1.0 - (1.0 - 0.9)*(1.0 - 0.9))
end

mutable struct MinPath
    len::Int
    set::Vector{Vector{Bool}}
end

function findminpath(f::AbstractNonTerminalNode, path::Vector{Bool}, s::MinPath)
    if s.len < sum(path)
        return
    end
    path[level(f)] = false
    findminpath(get_zero(f), path, s)
    path[level(f)] = true
    findminpath(get_one(f), path, s)
    path[level(f)] = false
    nothing
end

function findminpath(f::AbstractTerminalNode, path::Vector{Bool}, s::MinPath)
    if isone(f)
        if s.len > sum(path)
            s.len = sum(path)
            s.set = [copy(path)]
        elseif s.len == sum(path)
            push!(s.set, copy(path))
        end
    end
    nothing
end

function findmaxpath(f::AbstractNonTerminalNode, path::Vector{Bool}, s::MinPath)
    if s.len > sum(path)
        return
    end
    path[level(f)] = true
    findmaxpath(get_one(f), path, s)
    path[level(f)] = false
    findmaxpath(get_zero(f), path, s)
    path[level(f)] = true
    nothing
end

function findmaxpath(f::AbstractTerminalNode, path::Vector{Bool}, s::MinPath)
    if iszero(f)
        if s.len < sum(path)
            s.len = sum(path)
            s.set = [copy(path)]
        elseif s.len == sum(path)
            push!(s.set, copy(path))
        end
    end
    nothing
end

@testset "FT2" begin
    b = bdd()
    defvar!(b, :x, 1)
    defvar!(b, :y, 2)
    defvar!(b, :z, 3)
    x = var!(b, :x)
    y = var!(b, :y)
    z = var!(b, :z)

    f = (x + y) * z

    println(todot(f))

    path = [false for _ = b.headers]
    s = MinPath(length(b.headers), Vector{Bool}[])
    findminpath(f, path, s)
    println(s)
end

@testset "FT2-2" begin
    b = bdd()
    defvar!(b, :x, 1)
    defvar!(b, :y, 2)
    defvar!(b, :z, 3)
    x = var!(b, :x)
    y = var!(b, :y)
    z = var!(b, :z)

    f = (x + y) * z

    println(todot(f))

    path = [true for _ = b.headers]
    s = MinPath(0, Vector{Bool}[])
    findmaxpath(f, path, s)
    println("maxpath", s)
end

function mcs(b, f, vars, labels)
    path = [false for _ = vars]
    s = MinPath(length(vars), Vector{Bool}[])
    findminpath(f, path, s)

    mp = b.zero
    result = Vector{Symbol}[]
    for x = s.set
        tmp = b.one
        tmp2 = Symbol[]
        for (i,v) = enumerate(x)
            if v == true
                tmp = and(tmp, vars[i])
                push!(tmp2, labels[i])
            end
        end
        mp = or(mp, tmp)
        push!(result, tmp2)
    end
    result, not(imp(f, mp))
end

# function mcs(b, f, vars, labels)
#     path = [false for _ = vars]
#     s = MinPath(length(vars), Vector{Bool}[])
#     findminpath(f, path, s)

#     mp = b.zero
#     result = Vector{Symbol}[]
#     for x = s.set
#         tmp = b.one
#         tmp2 = Symbol[]
#         for (i,v) = enumerate(x)
#             if v == true
#                 tmp = and(tmp, vars[i])
#                 push!(tmp2, labels[i])
#             else
#                 tmp = and(tmp, not(vars[i]))
#                 push!(tmp2, Symbol("~", labels[i]))
#             end
#         end
#         mp = or(mp, tmp)
#         push!(result, tmp2)
#     end
#     result, not(imp(f, mp))
# end

function mcs(b, f)
    vars = Dict([level(x) => var!(b, k) for (k,x) = b.headers]...)
    labels = Dict([level(x) => k for (k,x) = b.headers]...)

    result = []
    while !iszero(f)
        tmp, f = mcs(b, f, vars, labels)
        push!(result, tmp...)
    end
    result
end

@testset "FT3" begin
    b = bdd()
    defvar!(b, :x, 1)
    defvar!(b, :y, 2)
    defvar!(b, :z, 3)
    x = var!(b, :x)
    y = var!(b, :y)
    z = var!(b, :z)

    f = (x + y) + z

    println(todot(f))

    vars = Dict([level(x) => var!(b, k) for (k,x) = b.headers]...)
    labels = Dict([level(x) => k for (k,x) = b.headers]...)

    res, f = mcs(b, f, vars, labels)
    println(todot(f))
    println(res)
end

@testset "FT4" begin
    b = bdd()
    defvar!(b, :x, 1)
    defvar!(b, :y, 2)
    defvar!(b, :z, 3)
    x = var!(b, :x)
    y = var!(b, :y)
    z = var!(b, :z)

    f = (x + y) * z + x

    println(todot(f))

    res = mcs(b, f)
    println(res)
end

function tomat(x::AbstractNode)
    visited = Set{NodeID}([])
    results = Tuple{Int,Int}[]
    _tomat(x, visited, results)
    results
end

function _tomat(x::AbstractNonTerminalNode, visited, results)
    if !in(id(x), visited)
        b0 = get_zero(x)
        push!(results, (id(x), id(b0)))
        _tomat(b0, visited, results)
        b1 = get_one(x)
        push!(results, (id(x), id(b1)))
        _tomat(get_one(x), visited, results)
        push!(visited, id(x))
    end
end

function _tomat(x::AbstractTerminalNode, visited, results)
    if !in(id(x), visited)
        push!(visited, id(x))
    end
end

@testset "FT5" begin
    b = bdd()
    defvar!(b, :x, 1)
    defvar!(b, :y, 2)
    defvar!(b, :z, 3)
    x = var!(b, :x)
    y = var!(b, :y)
    z = var!(b, :z)

    f = (x + y) * z + x

    println(tomat(f))
end

function mps(b, f, vars, labels)
    path = [true for _ = vars]
    s = MinPath(0, Vector{Bool}[])
    findmaxpath(f, path, s)

    mp = b.one
    result = Vector{Symbol}[]
    for x = s.set
        tmp = b.zero
        tmp2 = Symbol[]
        for (i,v) = enumerate(x)
            if v == true
                push!(tmp2, labels[i])
            else
                tmp = or(tmp, vars[i])
            end
        end
        mp = and(mp, tmp)
        push!(result, tmp2)
    end
    result, imp(mp, f)
end

# function mps(b, f, vars, labels)
#     path = [true for _ = vars]
#     s = MinPath(0, Vector{Bool}[])
#     findmaxpath(f, path, s)

#     mp = b.one
#     result = Vector{Symbol}[]
#     for x = s.set
#         tmp = b.zero
#         tmp2 = Symbol[]
#         for (i,v) = enumerate(x)
#             if v == true
#                 push!(tmp2, labels[i])
#                 tmp = or(tmp, not(vars[i]))
#             else
#                 tmp = or(tmp, vars[i])
#             end
#         end
#         mp = and(mp, tmp)
#         push!(result, tmp2)
#     end
#     println("*******:")
#     println(todot(mp))
#     result, imp(mp, f)
# end

function mps(b, f)
    vars = Dict([level(x) => var!(b, k) for (k,x) = b.headers]...)
    labels = Dict([level(x) => k for (k,x) = b.headers]...)

    result = []
    while !isone(f)
        tmp, f = mps(b, f, vars, labels)
        push!(result, tmp...)
    end
    result
end

@testset "FT4-2" begin
    b = bdd()
    defvar!(b, :A, 1)
    defvar!(b, :B, 2)
    defvar!(b, :C, 3)
    A = var!(b, :A)
    B = var!(b, :B)
    C = var!(b, :C)

    f = A + B * C

    println(todot(f))
    res = mcs(b, f)
    println("MCS ", res)

    res = mps(b, f)
    println("MPS ", res)
end

@testset "FT4-3" begin
    b = bdd()
    defvar!(b, :A, 1)
    defvar!(b, :B, 2)
    defvar!(b, :C, 3)
    A = var!(b, :A)
    B = var!(b, :B)
    C = var!(b, :C)

    f = xor(A, B * C)

    println(todot(f))
    res = mcs(b, f)
    println("MCS ", res)

    res = mps(b, f)
    println("MPS ", res)
end

@testset "FT10" begin
    function prob(f::AbstractNonTerminalNode, pb, cache)
        get!(cache, id(f)) do
            x = label(f)
            p = pb[x]
            pbar = 1.0 - p
    
            b0 = prob(get_zero(f), pb, cache)
            b1 = prob(get_one(f), pb, cache)
    
            pbar * b0 + p * b1
        end
    end
    
    function prob(f::AbstractTerminalNode, pb, cache)
        get!(cache, id(f)) do
            if iszero(f)
                0.0
            else
                1.0
            end
        end
    end
    
    b = bdd()
    defvar!(b, :x, 1)
    defvar!(b, :y, 2)
    defvar!(b, :z, 3)
    x = var!(b, :x)
    y = var!(b, :y)
    z = var!(b, :z)

    f = (x + y) * z
    println(todot(f))
    pb = Dict(:x=>0.9, :y=>0.9, :z=>0.9)
    cache = Dict()
    println(prob(f, pb, cache))

    # abstract type AbstractEdge end

    # struct EdgeRoot <: AbstractEdge end

    # struct Edge0 <: AbstractEdge
    #     parent::AbstractNode
    # end

    # struct Edge1 <: AbstractEdge
    #     parent::AbstractNode
    # end

    # function makegraph(f::AbstractNonTerminalNode, parent, res, visited)
    #     parents = get(res, id(f), AbstractEdge[])
    #     push!(parents, parent)
    #     res[id(f)] = parents
    #     if !in(id(f), visited)
    #         makegraph(get_zero(f), Edge0(f), res, visited)
    #         makegraph(get_one(f), Edge1(f), res, visited)
    #         push!(visited, id(f))
    #     end
    # end

    # function makegraph(f::AbstractTerminalNode, parent, res, visited)
    #     parents = get(res, id(f), AbstractEdge[])
    #     push!(parents, parent)
    #     res[id(f)] = parents
    # end

    result = reversetree(f)
    println(result)

    function grad(f::EdgeRoot, pb, values, edges, gradedge, gradpb)
        1.0
    end

    function grad(f::AbstractEdge, pb, values, edges, gradedge, gradpb)
        get(gradedge, f) do
            nodegrad(f.parent, pb, values, edges, gradedge, gradpb)
            gradedge[f]
        end
    end

    function nodegrad(f::AbstractNode, pb, values, edges, gradedge, gradpb)
        local x = label(f)
        p = pb[x]
        pbar = 1.0 - p

        local x0 = values[id(get_zero(f))]
        local x1 = values[id(get_one(f))]

        local glow = 0.0
        local ghigh = 0.0
        local gpb = 0.0
        for e = edges[id(f)]
            gout = grad(e, pb, values, edges, gradedge, gradpb)
            ghigh += gout * p
            glow += gout * pbar
            gpb += gout * (x1-x0)
        end
        gradedge[Edge0(f)] = glow
        gradedge[Edge1(f)] = ghigh
        gradpb[x] = gpb
        nothing
    end

    gradedge = Dict()
    gradpb = Dict()

    for e = result[id(b.one)]
        grad(e, pb, cache, result, gradedge, gradpb)
    end

    println(gradedge)
    println(gradpb)

    # function grad(f::AbstractNonTerminalNode, pb, cache, gradcache, outid, edge)
    #     x = label(f)
    #     p = pb[x]
    #     pbar = 1.0 - p

    #     gout = get(gradcache, (outid, edge))

    #     glow = get(gradcache, (id(f), :low), 0.0)
    #     glow += gout * pbar
    #     gradcache[(id(f), :low)] = glow

    #     ghigh = get(gradcache, (id(f), :high), 0.0)
    #     ghigh += gout * p
    #     gradcache[(id(f), :high)] = ghigh

    #     gpb = gradcache[x]
    #     x0 = cache[id(get_zero(f))]
    #     x1 = cache[id(get_one(f))]
    #     gpb += gout * (x1-x0)
    #     gradcache[x] = gpb
    # end
end

end

