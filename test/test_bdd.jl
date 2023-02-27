module BDDTest

using DD.BDD
using Test

import DD.BDD: node

@testset "BDD1" begin
    b = bdd()
    addvar!(b, :x, 1)
    addvar!(b, :y, 2)
    addvar!(b, :z, 3)
    x = var(b, :x)
    y = var(b, :y)
    z = var(b, :z)
    println(x)
    println(todot(x))
end

@testset "BDD2" begin
    b = bdd()
    addvar!(b, :x, 1)
    addvar!(b, :y, 2)
    x = var(b, :x)
    y = var(b, :y)
    z = and(x, y)
    println(todot(z))

    tmp = node(b, x.header, b.zero, b.one)
    tmp = node(b, y.header, b.zero, tmp)
    @test z.id == tmp.id

end

@testset "BDD3" begin
    b = bdd()
    addvar!(b, :x, 1)
    addvar!(b, :y, 2)
    x = var(b, :x)
    y = var(b, :y)
    z = or(x, y)
    println(todot(z))

    tmp = node(b, x.header, b.zero, b.one)
    tmp = node(b, y.header, tmp, b.one)
    @test z.id == tmp.id
end

@testset "BDD4" begin
    b = bdd()
    addvar!(b, :x, 1)
    addvar!(b, :y, 2)
    addvar!(b, :z, 3)
    x = var(b, :x)
    y = var(b, :y)
    z = var(b, :z)
    result1 = ifthenelse(x, y, z)
    println(todot(result1))
end

@testset "BDD5" begin
    b = bdd()
    addvar!(b, :x, 1)
    addvar!(b, :y, 2)
    addvar!(b, :z, 3)
    x = var(b, :x)
    y = var(b, :y)
    z = var(b, :z)
    result1 = xor(x, y)
    println(todot(result1))
end

@testset "BDD6" begin
    b = bdd()
    addvar!(b, :x, 1)
    addvar!(b, :y, 2)
    addvar!(b, :z, 3)
    x = var(b, :x)
    y = var(b, :y)
    z = var(b, :z)
    result1 = imp(x, y)
    println(todot(result1))
end

@testset "BDD7" begin
    b = bdd()
    addvar!(b, :x, 1)
    addvar!(b, :y, 2)
    addvar!(b, :z, 3)
    x = var(b, :x)
    y = var(b, :y)
    z = var(b, :z)
    result1 = (x & y) | z
    println(todot(result1))
    result2 = (x * y) + z
    println(todot(result2))
    @test result1.id == result2.id
end

@testset "BDD8" begin
    b = bdd()
    addvar!(b, :x, 1)
    addvar!(b, :y, 2)
    addvar!(b, :z, 3)
    x = var(b, :x)
    y = var(b, :y)
    z = var(b, :z)
    result1 = true | (x & y)
    println(todot(result1))
    result2 = true + (x * y)
    println(todot(result2))
    @test result1.id == result2.id
end

@testset "BDD9" begin
    b = bdd()
    addvar!(b, :x, 1)
    addvar!(b, :y, 2)
    addvar!(b, :z, 3)
    x = var(b, :x)
    y = var(b, :y)
    z = var(b, :z)
    result1 = z | (x & y)
    println(level(result1))
    println(level(get_zero(result1)))
end

@testset "BDD10" begin
    b = bdd(QuasiReduced())
    addvar!(b, :x, 1)
    addvar!(b, :y, 2)
    addvar!(b, :z, 3)
    x = var(b, :x)
    y = var(b, :y)
    z = var(b, :z)
    result1 = z | (x & y)
    println(todot(result1))
    println(b)
end

end

