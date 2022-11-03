import DD.MultiState: MSS, var!, mdd, prob
import DD.MDD: todot, ifelse, @match, and, or
using Random

@testset "MSS1" begin
    mss = MSS()
    x1 = var!(mss, :x1, [0,1])
    x2 = var!(mss, :x2, [0,1,2])
    x3 = var!(mss, :x3, [0,1,2])

    println(mss)
    println(mdd(mss))
end

@testset "MSS2" begin
    mss = MSS()
    x1 = var!(mss, :x1, [0,1])
    x2 = var!(mss, :x2, [0,1,2])
    x3 = var!(mss, :x3, [0,1,2])

    x = x2 >= 1
    println(todot(x))
end

@testset "MSS3" begin
    mss = MSS()
    x1 = var!(mss, :x1, [0,1])
    x2 = var!(mss, :x2, [0,1,2])
    x3 = var!(mss, :x3, [0,1,2])

    x = x1 >= 1
    x = ifelse(x, 2, 3)
    println(todot(x))
end

@testset "MSS6" begin
    mss = MSS()
    x1 = var!(mss, :x1, [0,1])
    x2 = var!(mss, :x2, [0,1,2])
    x3 = var!(mss, :x3, [0,1,2])

    x = @match(
        x1 == 0 => 0,
        x2 == 0 && x3 == 0 => 0,
        x2 == 0 || x3 == 0 => 1,
        x2 == 2 || x3 == 2 => 3,
        _ => 2)
    println(todot(x))
end

@testset "MSS7" begin
    mss = MSS()
    x3 = var!(mss, :x3, [0,1,2])
    x2 = var!(mss, :x2, [0,1,2])
    x1 = var!(mss, :x1, [0,1])

    x = @match(
        x1 == 0 => 0,
        x2 == 0 && x3 == 0 => 0,
        x2 == 0 || x3 == 0 => 1,
        x2 == 2 || x3 == 2 => 3,
        _ => 2)

    y = @match(
        x == 0 || x2 == 1 => 100,
        x2 == 2 => 200,
        _ => 1)

    println(todot(y))
end

@testset "MSS8" begin
    mss = MSS()
    x1 = var!(mss, :x1, [0,1])
    x2 = var!(mss, :x2, [0,1])
    x3 = var!(mss, :x3, [0,1,2])

    s1 = @match(
        x1 == 1 || x2 == 1 => 1,
        _ => 0)

    s2 = @match(
        x2 == 0 && x3 == 0 => 0,
        x2 == 0 => 1,
        x3 == 2 => 2,
        _ => 0)

    s3 = min(s1, s2)
    println(todot(s1))
    println(todot(s2))
    println(todot(s3))
end

@testset "MSS9" begin
    mss = MSS()
    C = var!(mss, :C, [0,1,2])
    B = var!(mss, :B, [0,1,2])
    A = var!(mss, :A, [0,1])

    g1 = (x, y) -> @match(
        x == 0 => 0,
        _ => y
    )

    g2 = (x, y) -> @match(
        x == 0 && y == 0 => 0,
        x == 0 || y == 0 => 1,
        x == 2 || y == 2 => 3,
        _ => 2
    )

    Sx = g2(B, C)
    SS = g1(A, Sx)

    println(todot(SS))
end

@testset "MSS10" begin
    mss = MSS()
    C = var!(mss, :C, [0,1,2])
    B = var!(mss, :B, [0,1,2])
    A = var!(mss, :A, [0,1])

    p = Dict([
        :A => [0.2, 0.8],
        :B => [0.2, 0.2, 0.6],
        :C => [0.1, 0.3, 0.6]
    ])

    Sx = @match(
        B == 0 && C == 0 => 0,
        B == 0 || C == 0 => 1,
        B == 2 || C == 2 => 3,
        _ => 2)

    SS = @match(
        A == 0 => 0,
        _ => Sx)

    println([prob(SS, p, v) for v = [0,1,2,3]])
end

