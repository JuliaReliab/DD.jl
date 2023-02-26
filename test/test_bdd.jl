module BDDTest

using DD.BDD
using Test

import DD.BDD: node

@testset "BDD1" begin
    b = bdd()
    x = var!(b, :x, 1)
    y = var!(b, :y, 2)
    z = var!(b, :z, 3)
    println(x)
    println(todot(x))
end

@testset "BDD2" begin
    b = bdd()
    x = var!(b, :x, 1)
    y = var!(b, :y, 2)
    z = and(x, y)
    println(todot(z))

    tmp = node(b, x.header, b.zero, b.one)
    tmp = node(b, y.header, b.zero, tmp)
    @test z.id == tmp.id

end

@testset "BDD3" begin
    b = bdd()
    x = var!(b, :x, 1)
    y = var!(b, :y, 2)
    z = or(x, y)
    println(todot(z))

    tmp = node(b, x.header, b.zero, b.one)
    tmp = node(b, y.header, tmp, b.one)
    @test z.id == tmp.id
end

@testset "BDD4" begin
    b = bdd()
    x = var!(b, :x, 1)
    y = var!(b, :y, 2)
    z = var!(b, :z, 3)
    result1 = ifthenelse(x, y, z)
    println(todot(result1))
end

@testset "BDD5" begin
    b = bdd()
    x = var!(b, :x, 1)
    y = var!(b, :y, 2)
    z = var!(b, :z, 3)
    result1 = xor(x, y)
    println(todot(result1))
end

@testset "BDD6" begin
    b = bdd()
    x = var!(b, :x, 1)
    y = var!(b, :y, 2)
    z = var!(b, :z, 3)
    result1 = imp(x, y)
    println(todot(result1))
end

@testset "BDD7" begin
    b = bdd()
    x = var!(b, :x, 1)
    y = var!(b, :y, 2)
    z = var!(b, :z, 3)
    result1 = (x & y) | z
    println(todot(result1))
    result2 = (x * y) + z
    println(todot(result2))
    @test result1.id == result2.id
end

end

