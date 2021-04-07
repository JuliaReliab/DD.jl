using DD
using Test

@testset "DDtest1" begin
    forest = BDD()
    x = var(forest, :x)
    y = var(forest, :y)
    z = var(forest, :z)
    f1 = and(forest, x, y)
    f2 = or(forest, x, y)
    f3 = ite(forest, x, y, z)
    @test x.low == forest.zero
    @test x.high == forest.one
    @test y.low == forest.zero
    @test y.high == forest.one
    @test z.low == forest.zero
    @test z.high == forest.one
    @test f1.high.high == forest.one
    @test f1.high.low == forest.zero
    @test f1.low == forest.zero
    @test f2.low.low == forest.zero
    @test f2.low.high == forest.one
    @test f2.high == forest.one
end

@testset "DDtest2" begin
    forest = BDD()
    x = var(forest, :x)
    y = var(forest, :y)
    z = var(forest, :z)
    f1 = and(forest, x, y)
    f2 = or(forest, x, y)
    f3 = ite(forest, x, y, z)
    println(todot(forest, f1))
    println(todot(forest, f2))
    println(todot(forest, f3))
end

@testset "DDtest3" begin
    forest = BDD2()
    x = var(forest, :x)
    y = var(forest, :y)
    z = var(forest, :z)
    f1 = and(forest, x, y)
    f2 = or(forest, x, y)
    # f3 = ite(forest, x, y, z)
    # @test x.low == forest.zero
    # @test x.high == forest.one
    # @test y.low == forest.zero
    # @test y.high == forest.one
    # @test z.low == forest.zero
    # @test z.high == forest.one
    # @test f1.high.high == forest.one
    # @test f1.high.low == forest.zero
    # @test f1.low == forest.zero
    # @test f2.low.low == forest.zero
    # @test f2.low.high == forest.one
    # @test f2.high == forest.one
end

@testset "DDtest4" begin
    forest = BDD2()
    x = var(forest, :x)
    y = var(forest, :y)
    z = var(forest, :z)
    f1 = and(forest, x, y)
    f2 = or(forest, x, y)
    f3 = ite(forest, x, y, z)
    println(todot(forest, f1))
    println(todot(forest, f2))
    println(todot(forest, f3))
end
