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

    mp = b.zero
    result = Vector{Symbol}[]
    for x = s.set
        tmp = b.zero
        tmp2 = Symbol[]
        for (i,v) = enumerate(x)
            if v == false
                tmp = and(tmp, not(vars[i]))
            else
                push!(tmp2, labels[i])
            end
        end
        mp = or(mp, tmp)
        push!(result, tmp2)
    end
    result, imp(mp, f)
end

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

    f = (A + B) * C

    println(todot(f))
    res = mcs(b, f)
    println("4-2", res)

    res = mps(b, f)
    println("4-2", res)
end

end

