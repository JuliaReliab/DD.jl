module BDDTest

using DD.BDD
using Test

@testset "BDD1" begin
    b = bdd()
    defvar!(b, :x, 1)
    defvar!(b, :y, 2)
    defvar!(b, :z, 3)
    x = var!(b, :x)
    y = var!(b, :y)
    z = var!(b, :z)
    println(x)
    println(todot(x))
end

@testset "BDD2" begin
    b = bdd()
    defvar!(b, :x, 1)
    defvar!(b, :y, 2)
    x = var!(b, :x)
    y = var!(b, :y)
    z = and(x, y)
    println(todot(z))

    tmp = node!(b, x.header, b.zero, b.one)
    tmp = node!(b, y.header, b.zero, tmp)
    @test z.id == tmp.id
end

@testset "BDD2-2" begin
    b = bdd()
    defvar!(b, :x, 1)
    defvar!(b, :y, 2)
    x = var!(b, :x)
    y = var!(b, :y)
    z = and(x, y)
    println(todot(z))

    tmp = node!(b, :x, false, true)
    tmp = node!(b, :y, false, tmp)
    @test z.id == tmp.id
end

@testset "BDD3" begin
    b = bdd()
    defvar!(b, :x, 1)
    defvar!(b, :y, 2)
    x = var!(b, :x)
    y = var!(b, :y)
    z = or(x, y)
    println(todot(z))

    tmp = node!(b, x.header, b.zero, b.one)
    tmp = node!(b, y.header, tmp, b.one)
    @test z.id == tmp.id
end

@testset "BDD4" begin
    b = bdd()
    defvar!(b, :x, 1)
    defvar!(b, :y, 2)
    defvar!(b, :z, 3)
    x = var!(b, :x)
    y = var!(b, :y)
    z = var!(b, :z)
    result1 = ifthenelse(x, y, z)
    println(todot(result1))
end

@testset "BDD5" begin
    b = bdd()
    defvar!(b, :x, 1)
    defvar!(b, :y, 2)
    defvar!(b, :z, 3)
    x = var!(b, :x)
    y = var!(b, :y)
    z = var!(b, :z)
    result1 = xor(x, y)
    println(todot(result1))
end

@testset "BDD6" begin
    b = bdd()
    defvar!(b, :x, 1)
    defvar!(b, :y, 2)
    defvar!(b, :z, 3)
    x = var!(b, :x)
    y = var!(b, :y)
    z = var!(b, :z)
    result1 = imp(x, y)
    println(todot(result1))
end

@testset "BDD7" begin
    b = bdd()
    defvar!(b, :x, 1)
    defvar!(b, :y, 2)
    defvar!(b, :z, 3)
    x = var!(b, :x)
    y = var!(b, :y)
    z = var!(b, :z)
    result1 = (x & y) | z
    println(todot(result1))
    result2 = (x * y) + z
    println(todot(result2))
    @test result1.id == result2.id
end

@testset "BDD8" begin
    b = bdd()
    defvar!(b, :x, 1)
    defvar!(b, :y, 2)
    defvar!(b, :z, 3)
    x = var!(b, :x)
    y = var!(b, :y)
    z = var!(b, :z)
    result1 = true | (x & y)
    println(todot(result1))
    result2 = true + (x * y)
    println(todot(result2))
    @test result1.id == result2.id
end

@testset "BDD9" begin
    b = bdd()
    defvar!(b, :x, 1)
    defvar!(b, :y, 2)
    defvar!(b, :z, 3)
    x = var!(b, :x)
    y = var!(b, :y)
    z = var!(b, :z)
    result1 = z | (x & y)
    println(level(result1))
    println(level(get_zero(result1)))
end

@testset "BDD10" begin
    b = bdd(QuasiReduced())
    defvar!(b, :x, 1)
    defvar!(b, :y, 2)
    defvar!(b, :z, 3)
    x = var!(b, :x)
    y = var!(b, :y)
    z = var!(b, :z)
    result1 = z | (x & y)
    println(todot(result1))
    println(b)
end

@testset "BDD11" begin
    b = bdd()
    defvar!(b, :x, 1)
    defvar!(b, :y, 2)
    defvar!(b, :z, 3)
    f = [
        [false, false, true],
        [false, true, false],
        [true, false, false],
        [true, false, true],
        [true, true, false]
    ]
    x = genfunc!(b, f)
    println(todot(x))
end

@testset "BDD12" begin
    b = bdd()
    defvar!(b, :x, 1)
    defvar!(b, :y, 2)
    defvar!(b, :z, 3)
    f = [
        [false, false, true],
        [false, true, false],
        [true, false, false],
        [true, false, true],
        [true, true, false]
    ]
    x = genfunc!(b, f)
    h = Dict([k => level(v) for (k,v) = vars(b)])
    println(h)
end

end

