using DD.BDD

@testset "BDD1" begin
    b = bdd(Symbol)
    header!(b, :x)
    header!(b, :y)
    header!(b, :z)
    println(b.headers)
end

@testset "BDD2" begin
    b = bdd(Symbol)
    header!(b, :x)
    header!(b, :y)
    x = var!(b, :x)
    y = var!(b, :y)
    z = and(b, x, y)
    println(todot(b, z))

    tmp = node!(b, header!(b, :x), b.zero, b.one)
    tmp = node!(b, header!(b, :y), b.zero, tmp)
    @test z.id == tmp.id
end

@testset "BDD3" begin
    b = bdd(Symbol)
    x = var!(b, :x)
    y = var!(b, :y)
    z = or(b, x, y)
    println(todot(b, z))

    tmp = node!(b, header!(b, :x), b.zero, b.one)
    tmp = node!(b, header!(b, :y), tmp, b.one)
    @test z.id == tmp.id
end

@testset "BDD4" begin
    b = bdd(Symbol)
    x = var!(b, :x)
    y = var!(b, :y)
    z = var!(b, :z)
    result1 = and(b, or(b, x, y), z)
    println(todot(b, result1))

    result2 = or(b, and(b, not(b, x), not(b, y)), not(b, z))
    println(todot(b, result2))

    result3 = not(b, result1)
    @test result3.id == result2.id
end
