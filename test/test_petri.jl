module PetriTest

using DD
using Test

using DD.MDD
using Random

"""
getbounds(forest, f, lower, upper)
"""

function getbounds(f::AbstractNode, lower::Vector{DomainValue}, upper::Vector{DomainValue})
    cache = Dict()
    _getbounds!(f, lower, upper, cache)
end

function _getbounds!(f::AbstractTerminalNode{DomainValue}, ::Vector{DomainValue}, ::Vector{DomainValue}, cache)
    [f.value, f.value]
end

function _getbounds!(f::AbstractTerminalNode{Nothing}, ::Vector{DomainValue}, ::Vector{DomainValue}, cache)
    [nothing, nothing]
end

function _getbounds!(f::AbstractNonTerminalNode, lower::Vector{DomainValue}, upper::Vector{DomainValue}, cache)
    get(cache, id(f)) do
        m = Any[nothing, nothing]
        for i = f.header.index[lower[level(f)]]:f.header.index[upper[level(f)]]
            lres, ures = _getbounds!(get_nodes(f)[i], lower, upper, cache)
            if lres != nothing && (m[1] == nothing || lres < m[1])
                m[1] = lres
            end
            if ures != nothing && (m[2] == nothing || ures > m[2])
                m[2] = ures
            end
        end
        cache[id(f)] = m
    end
end

"""
getmaxbounds2(forest, f, lower, upper)
"""

function getbounds3(f::AbstractNode, lower::Vector{DomainValue}, upper::Vector{DomainValue}, id)
    result1 = []
    result2 = []
    _getidnode!(f, lower, upper, id, Set(), result1, result2)
    # println(result1)
    # println(result2)
    if length(result1) == 0 && length(result2) == 0
        [lower[id], upper[id]]
    else
        cache = Dict()
        m = [65535, -1]
        for x = result1
            _getbounds3!(x, lower, upper, cache)
            for v = lower[x.header.level]:upper[x.header.level]
                i = x.header.index[v]
                tmp = cache[x.nodes[i].id]
                if tmp[1] != nothing
                    m[1] = min(m[1], v + tmp[1])
                    m[2] = max(m[2], v + tmp[2])
                end
            end
            # println(todot(b, x))
        end
        # println("m", m)
        for x = result2
            tmp = _getbounds3!(x, lower, upper, cache)
            if tmp[1] != nothing
                m[1] = min(m[1], lower[id] + tmp[1])
                m[2] = max(m[2], upper[id] + tmp[2])
            end
        end
    end
    m
end

function _getidnode!(f::AbstractNode, lower::Vector{DomainValue}, upper::Vector{DomainValue}, id, visited, result1, result2)
    if in(f.id, visited)
        return
    end
    if f.header.level == id
        push!(visited, f.id)
        push!(result1, f)
        return
    end
    if f.header.level < id
        push!(visited, f.id)
        push!(result2, f)
        return
    end
    for v = lower[f.header.level]:upper[f.header.level]
        i = f.header.index[v]
        _getidnode!(f.nodes[i], lower, upper, id, visited, result1, result2)
        push!(visited, f.id)
    end
end

function _getidnode!(f::AbstractTerminalNode{DomainValue}, lower::Vector{DomainValue}, upper::Vector{DomainValue}, id, visited, result1, result2)
    if in(f.id, visited)
        return
    end
    push!(visited, f.id)
    push!(result2, f)
end

function _getidnode!(f::AbstractTerminalNode{Nothing}, lower::Vector{DomainValue}, upper::Vector{DomainValue}, id, visited, result1, result2)
    return
end

function _getbounds3!(f::AbstractTerminalNode{DomainValue}, ::Vector{DomainValue}, ::Vector{DomainValue}, cache)
    get(cache, f.id) do
        cache[f.id] = [f.value, f.value]
    end
end

function _getbounds3!(f::AbstractTerminalNode{Nothing}, ::Vector{DomainValue}, ::Vector{DomainValue}, cache)
    get(cache, f.id) do
        cache[f.id] = [nothing, nothing]
    end
end

function _getbounds3!(f::AbstractNode, lower::Vector{DomainValue}, upper::Vector{DomainValue}, cache)
    get(cache, f.id) do
        m = Any[nothing, nothing]
        for i = f.header.index[lower[f.header.level]]:f.header.index[upper[f.header.level]]
            lres, ures = _getbounds3!(f.nodes[i], lower, upper, cache)
            if lres != nothing && (m[1] == nothing || lres < m[1])
                m[1] = lres
            end
            if ures != nothing && (m[2] == nothing || ures > m[2])
                m[2] = ures
            end
        end
        cache[f.id] = m
    end
end

@testset "P1" begin
    b = mdd()
    defvar!(b, :x3, 1, 0:10)
    defvar!(b, :x2, 2, 0:10)
    defvar!(b, :x1, 3, 0:10)
    defvar!(b, :t1, 4, 0:1)
    defvar!(b, :t1dash, 5, 0:1)

    x3 = var!(b, :x3)
    x2 = var!(b, :x2)
    x1 = var!(b, :x1)
    t1 = var!(b, :t1)
    t1dash = var!(b, :t1dash)

    x1dash = @match(
        t1 == 1 && x1 >= 1 && x2 >= 1 && x3 < 10 => x1 - 1,
        _ => x1)

    x2dash = @match(
        t1 == 1 && x1 >= 1 && x2 >= 1 && x3 < 10 => x2 - 1,
        _ => x2)

    x3dash = @match(
        t1 == 1 && x1 >= 1 && x2 >= 1 && x3 < 10 => x3 + 1,
        _ => x3)

    x1dashdash = @match(
        t1dash == 2 && x1dash >= 1 && x2dash >= 1 && x3dash < 10 => x1dash - 1,
        _ => x1dash)

    println(todot(x1dashdash))
    # println(todot(x2dash))
    # println(todot(x3dash))
end

@testset "P2" begin
    b = mdd()
    n = 5
    for i = 1:6
        defvar!(b, Symbol(:x, i), i, 0:n)
    end
    defvar!(b, :t1, 7, 1:6)
    defvar!(b, :t2, 8, 1:6)

    x = [var!(b, Symbol(:x, i)) for i = 1:6]
    t1 = var!(b, :t1)
    t2 = var!(b, :t2)

    @time begin
        s = @match(
            x[2] - x[3] + x[4] - x[5] == 0 => 1,
            _ => nothing)

        x1dash = @match(
            s == 1 && t1 == 1 && x[1] < n => x[1] + 1,
            s == 1 && t1 == 2 && x[1] >= 1 && x[2] < n && x[3] < n => x[1] - 1,
            s == 1 => x[1],
            _ => nothing)

        x2dash = @match(
            s == 1 && t1 == 2 && x[1] >= 1 && x[2] < n && x[3] < n => x[2] + 1,
            s == 1 && t1 == 3 && x[2] >= 1 && x[4] < n => x[2] - 1,
            s == 1 => x[2],
            _ => nothing)

        x3dash = @match(
            s == 1 && t1 == 2 && x[1] >= 1 && x[2] < n && x[3] < n => x[3] + 1,
            s == 1 && t1 == 4 && x[3] >= 1 && x[5] < n => x[3] - 1,
            s == 1 => x[3],
            _ => nothing)

        x4dash = @match(
            s == 1 && t1 == 3 && x[2] >= 1 && x[4] < n => x[4] + 1,
            s == 1 && t1 == 5 && x[4] >= 1 && x[5] >= 1 && x[6] < n => x[4] - 1,
            s == 1 => x[4],
            _ => nothing)

        x5dash = @match(
            s == 1 && t1 == 4 && x[3] >= 1 && x[5] < n => x[5] + 1,
            s == 1 && t1 == 5 && x[4] >= 1 && x[5] >= 1 && x[6] < n => x[5] - 1,
            s == 1 => x[5],
            _ => nothing)

        x6dash = @match(
            s == 1 && t1 == 5 && x[4] >= 1 && x[5] >= 1 && x[6] < n => x[6] + 1,
            s == 1 && t1 == 6 && x[6] >= 1 => x[6] - 1,
            s == 1 => x[6],
            _ => nothing)

        x = [x1dash, x2dash, x3dash, x4dash, x5dash, x6dash]

        x1dash = @match(
            t2 == 1 && x[1] < n => x[1] + 1,
            t2 == 2 && x[1] >= 1 && x[2] < n && x[3] < n => x[1] - 1,
            _ => x[1])

        x2dash = @match(
            t2 == 2 && x[1] >= 1 && x[2] < n && x[3] < n => x[2] + 1,
            t2 == 3 && x[2] >= 1 && x[4] < n => x[2] - 1,
            _ => x[2])

        x3dash = @match(
            t2 == 2 && x[1] >= 1 && x[2] < n && x[3] < n => x[3] + 1,
            t2 == 4 && x[3] >= 1 && x[5] < n => x[3] - 1,
            _ => x[3])

        x4dash = @match(
            t2 == 3 && x[2] >= 1 && x[4] < n => x[4] + 1,
            t2 == 5 && x[4] >= 1 && x[5] >= 1 && x[6] < n => x[4] - 1,
            _ => x[4])

        x5dash = @match(
            t2 == 4 && x[3] >= 1 && x[5] < n => x[5] + 1,
            t2 == 5 && x[4] >= 1 && x[5] >= 1 && x[6] < n => x[5] - 1,
            _ => x[5])

        x6dash = @match(
            t2 == 5 && x[4] >= 1 && x[5] >= 1 && x[6] < n => x[6] + 1,
            t2 == 6 && x[6] >= 1 => x[6] - 1,
            _ => x[6])
    end

    # v = getbounds(x1dash, [0,0,0,0,0,0,6,6], [n,n,n,n,n,n,6,6])
    # println(v)

    rng = MersenneTwister(1234)
    lower = [0, 0, 0, 0, 0, 0]
    upper = [n, n, n, n, n, n]
    @time begin
        event = [rand(rng, 1:6), rand(rng, 1:6)]
        l = cat(lower, event, dims=1)
        u = cat(upper, event, dims=1)
        v1 = getbounds(x1dash, l, u)
        v2 = getbounds(x2dash, l, u)
        v3 = getbounds(x3dash, l, u)
        v4 = getbounds(x4dash, l, u)
        v5 = getbounds(x5dash, l, u)
        v6 = getbounds(x6dash, l, u)
        for (i,x) = enumerate([v1, v2, v3, v4, v5, v6])
            lower[i] = x[1]
            upper[i] = x[2]
        end
        println(lower, upper)
    end
    @time begin
        for k = 1:100
            event = [rand(rng, 1:6),rand(rng, 1:6)]
            l = cat(lower, event, dims=1)
            u = cat(upper, event, dims=1)
            v1 = getbounds(x1dash, l, u)
            v2 = getbounds(x2dash, l, u)
            v3 = getbounds(x3dash, l, u)
            v4 = getbounds(x4dash, l, u)
            v5 = getbounds(x5dash, l, u)
            v6 = getbounds(x6dash, l, u)
            for (i,x) = enumerate([v1, v2, v3, v4, v5, v6])
                lower[i] = x[1]
                upper[i] = x[2]
            end
            println(lower, upper)
        end
    end
end

@testset "P3" begin
    b = mdd()
    n = 5
    for i = 1:6
        defvar!(b, Symbol(:x, i), i, 0:n)
    end
    defvar!(b, :t1, 7, 1:6)
    defvar!(b, :t2, 8, 1:6)

    x = [var!(b, Symbol(:x, i)) for i = 1:6]
    x0 = x
    t1 = var!(b, :t1)
    t2 = var!(b, :t2)

    @time begin
        s = @match(
            x[2] - x[3] + x[4] - x[5] == 0 => 1,
            _ => nothing)

        x1dash = @match(
            s == 1 && t1 == 1 && x[1] < n => 1,
            s == 1 && t1 == 2 && x[1] >= 1 && x[2] < n && x[3] < n => -1,
            s == 1 => 0,
            _ => nothing)

        x2dash = @match(
            s == 1 && t1 == 2 && x[1] >= 1 && x[2] < n && x[3] < n => 1,
            s == 1 && t1 == 3 && x[2] >= 1 && x[4] < n => -1,
            s == 1 => 0,
            _ => nothing)

        x3dash = @match(
            s == 1 && t1 == 2 && x[1] >= 1 && x[2] < n && x[3] < n => 1,
            s == 1 && t1 == 4 && x[3] >= 1 && x[5] < n => -1,
            s == 1 => 0,
            _ => nothing)

        x4dash = @match(
            s == 1 && t1 == 3 && x[2] >= 1 && x[4] < n => 1,
            s == 1 && t1 == 5 && x[4] >= 1 && x[5] >= 1 && x[6] < n => -1,
            s == 1 => 0,
            _ => nothing)

        x5dash = @match(
            s == 1 && t1 == 4 && x[3] >= 1 && x[5] < n => 1,
            s == 1 && t1 == 5 && x[4] >= 1 && x[5] >= 1 && x[6] < n => -1,
            s == 1 => 0,
            _ => nothing)

        x6dash = @match(
            s == 1 && t1 == 5 && x[4] >= 1 && x[5] >= 1 && x[6] < n => 1,
            s == 1 && t1 == 6 && x[6] >= 1 => -1,
            s == 1 => 0,
            _ => nothing)

        dx = [x1dash, x2dash, x3dash, x4dash, x5dash, x6dash]
        x = [x[i] + dx[i] for i = 1:6]

        x1dash = @match(
            t2 == 1 && x[1] < n => dx[1] + 1,
            t2 == 2 && x[1] >= 1 && x[2] < n && x[3] < n => dx[1] - 1,
            _ => dx[1])

        x2dash = @match(
            t2 == 2 && x[1] >= 1 && x[2] < n && x[3] < n => dx[2] + 1,
            t2 == 3 && x[2] >= 1 && x[4] < n => dx[2] - 1,
            _ => dx[2])

        x3dash = @match(
            t2 == 2 && x[1] >= 1 && x[2] < n && x[3] < n => dx[3] + 1,
            t2 == 4 && x[3] >= 1 && x[5] < n => dx[3] - 1,
            _ => dx[3])

        x4dash = @match(
            t2 == 3 && x[2] >= 1 && x[4] < n => dx[4] + 1,
            t2 == 5 && x[4] >= 1 && x[5] >= 1 && x[6] < n => dx[4] - 1,
            _ => dx[4])

        x5dash = @match(
            t2 == 4 && x[3] >= 1 && x[5] < n => dx[5] + 1,
            t2 == 5 && x[4] >= 1 && x[5] >= 1 && x[6] < n => dx[5] - 1,
            _ => dx[5])

        x6dash = @match(
            t2 == 5 && x[4] >= 1 && x[5] >= 1 && x[6] < n => dx[6] + 1,
            t2 == 6 && x[6] >= 1 => dx[6] - 1,
            _ => dx[6])
    end

    rng = MersenneTwister(1234)
    lower = [0, 0, 0, 0, 0, 0]
    upper = [n, n, n, n, n, n]
    @time begin
        event = [4, 5] #rand(rng, 1:6), rand(rng, 1:6)]
        println(event)
        l = cat(lower, event, dims=1)
        u = cat(upper, event, dims=1)
        v1 = getbounds3(x1dash, l, u, 1)
        v2 = getbounds3(x2dash, l, u, 2)
        v3 = getbounds3(x3dash, l, u, 3)
        v4 = getbounds3(x4dash, l, u, 4)
        v5 = getbounds3(x5dash, l, u, 5)
        v6 = getbounds3(x6dash, l, u, 6)
        for (i,x) = enumerate([v1, v2, v3, v4, v5, v6])
            lower[i] = x[1]
            upper[i] = x[2]
        end
        println(lower, upper)
    end
    @time begin
        for k = 1:100
            event = [rand(rng, 1:6),rand(rng, 1:6)]
            l = cat(lower, event, dims=1)
            u = cat(upper, event, dims=1)
            v1 = getbounds3(x1dash, l, u, 1)
            v2 = getbounds3(x2dash, l, u, 2)
            v3 = getbounds3(x3dash, l, u, 3)
            v4 = getbounds3(x4dash, l, u, 4)
            v5 = getbounds3(x5dash, l, u, 5)
            v6 = getbounds3(x6dash, l, u, 6)
            for (i,x) = enumerate([v1, v2, v3, v4, v5, v6])
                lower[i] = x[1]
                upper[i] = x[2]
            end
            println(lower, upper)
        end
    end
    println(lower, upper)
end


end
