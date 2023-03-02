module MDDTest

using DD.MDD
using Test

# import DD.MDD: MDDForest, NodeHeader, Terminal, Node, AbstractNode, todot, apply!, MDDMin, MDDMax
# import DD.MDD: var!, gte!, lt!, gt!, lte!, eq!, neq!, ifthenelse!, and!, or!, max!, min!, plus!, minus!, mul!, ValueT
# import DD.MDD: MDDIf, MDDElse, mdd, and, or, ifthenelse, @match

@testset "MDD1" begin
    b = mdd()
    defvar!(b, :x, 1, 0:3)
    defvar!(b, :y, 2, 0:3)
    defvar!(b, :z, 3, 0:3)
    x = var!(b, :x)
    y = var!(b, :y)
    z = var!(b, :z)
    println(x)
    println(todot(x))
end

@testset "MDD2" begin
    b = mdd()
    defvar!(b, :x, 1, 1:3)
    defvar!(b, :y, 2, 1:3)
    defvar!(b, :z, 3, 1:2)
    x = var!(b, :x)
    y = var!(b, :y)
    z = var!(b, :z)
    v = max!(b, min!(b, x, y), z)
    println(v)
    println(todot(v))
end

@testset "MDD5" begin
    b = mdd()
    defvar!(b, :x, 1, 0:5)
    defvar!(b, :y, 2, 0:2)
    x = var!(b, :x)
    y = var!(b, :y)
    z = !(y + x > 3)
    println(todot(z))
end

@testset "MDD6" begin
    b = mdd()
    defvar!(b, :x, 1, 0:10)
    defvar!(b, :y, 2, 0:10)
    defvar!(b, :z, 3, 0:10)
    x = var!(b, :x)
    y = var!(b, :y)
    z = var!(b, :z)
    a = and!(b, x > 5, or!(b, y <= 3, z != 6))
    println(todot(a))
end

@testset "MDD7" begin
    b = mdd()
    defvar!(b, :x, 1, 0:1)
    defvar!(b, :y, 2, 0:1)
    defvar!(b, :z, 3, 0:1)
    x = var!(b, :x)
    y = var!(b, :y)
    z = var!(b, :z)
    a = x + y + z == 1
    println(todot(a))
end

@testset "MDD8" begin
    b = mdd()
    defvar!(b, :x, 1, 0:1)
    defvar!(b, :y, 2, 0:1)
    defvar!(b, :z, 3, 0:1)
    x = var!(b, :x)
    y = var!(b, :y)
    z = var!(b, :z)
    a = 5*x + 8*y - 2*z >=4
    println(todot(a))
end

@testset "MDD9" begin
    b = mdd()
    defvar!(b, :x, 1, 0:10)
    defvar!(b, :y, 2, 0:10)
    defvar!(b, :z, 3, 0:10)
    x = var!(b, :x)
    y = var!(b, :y)
    z = var!(b, :z)
    a = and(x > 5, y <= 3, z != 6)
    println(todot(a))
end

@testset "MDD10" begin
    b = mdd()
    defvar!(b, :x, 1, 0:2)
    defvar!(b, :y, 2, 0:2)
    defvar!(b, :z, 3, 0:2)
    x = var!(b, :x)
    y = var!(b, :y)
    z = var!(b, :z)
    a = max(x + y, z)
    println(todot(a))
    a = min(x + y, z)
    a = @match(
        a == 2 => nothing,
        _ => a
    )
    println(todot(a))
    @test size(a) == (8, 14)
end

@testset "MDD11" begin
    b = mdd()
    defvar!(b, :x, 1, 0:2)
    defvar!(b, :y, 2, 0:2)
    defvar!(b, :z, 3, 0:2)
    x = var!(b, :x)
    y = var!(b, :y)
    z = var!(b, :z)
    a = ifthenelse(x + y >= 1, y, 1)
    println(todot(a))
end

@testset "MDD12" begin
    b = mdd()
    defvar!(b, :x, 1, 0:2)
    defvar!(b, :y, 2, 0:2)
    defvar!(b, :z, 3, 0:2)
    x = var!(b, :x)
    y = var!(b, :y)
    z = var!(b, :z)
    a = ifthenelse(x + y >= 1, z, nothing)
    println(todot(a))
end

@testset "Macro01" begin
    b = mdd()
    defvar!(b, :x, 1, 0:2)
    defvar!(b, :y, 2, 0:2)
    defvar!(b, :z, 3, 0:2)
    x = var!(b, :x)
    y = var!(b, :y)
    z = var!(b, :z)
    a = @macroexpand @match(
        x + y == 1 => 0,
        x + y == 2 => 1
    )
    println(a)
end

@testset "Macro02" begin
    b = mdd()
    defvar!(b, :x, 1, 0:2)
    defvar!(b, :y, 2, 0:2)
    defvar!(b, :z, 3, 0:2)
    x = var!(b, :x)
    y = var!(b, :y)
    z = var!(b, :z)
    a = @macroexpand @match(
        x + y == 1 && z == 0 => 0,
        _ => 1
    )
    println(a)
end

@testset "and01" begin
    b = mdd()
    a = and(false, and(value!(b, false), true))
    println(todot(a))
end

@testset "MSS6" begin
    b = mdd()
    defvar!(b, :x1, 3, [0,1])
    defvar!(b, :x2, 2, [0,1,2])
    defvar!(b, :x3, 1, [0,1,2])
    x1 = var!(b, :x1)
    x2 = var!(b, :x2)
    x3 = var!(b, :x3)
    x = @match(
        x1 == 0 => 0,
        x2 == 0 && x3 == 0 => 0,
        x2 == 0 || x3 == 0 => 1,
        x2 == 2 || x3 == 2 => 3,
        _ => 2)
    println(todot(x))
end

@testset "MSS7" begin
    b = mdd()
    defvar!(b, :x1, 3, [0,1])
    defvar!(b, :x2, 2, [0,1,2])
    defvar!(b, :x3, 1, [0,1,2])
    x1 = var!(b, :x1)
    x2 = var!(b, :x2)
    x3 = var!(b, :x3)
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
    b = mdd()
    defvar!(b, :x1, 3, [0,1])
    defvar!(b, :x2, 2, [0,1])
    defvar!(b, :x3, 1, [0,1,2])
    x1 = var!(b, :x1)
    x2 = var!(b, :x2)
    x3 = var!(b, :x3)

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
    b = mdd()
    defvar!(b, :A, 3, [0,1])
    defvar!(b, :B, 2, [0,1,2])
    defvar!(b, :C, 1, [0,1,2])
    A = var!(b, :A)
    B = var!(b, :B)
    C = var!(b, :C)

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

end
