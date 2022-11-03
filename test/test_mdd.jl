import DD.MDD: MDDForest, NodeHeader, Terminal, Node, AbstractNode, todot, apply!, MDDMin, MDDMax
import DD.MDD: var!, gte!, lt!, gt!, lte!, eq!, neq!, ifelse!, and!, or!, max!, min!, plus!, minus!, mul!, ValueT
import DD.MDD: MDDIf, MDDElse, mdd, and, or, ifelse

@testset "MDD1" begin
    b = MDDForest()
    h1 = NodeHeader(0, 1)
    h2 = NodeHeader(1, 2)
    println(h1)
end

@testset "MDD2" begin
    b = MDDForest()
    h1 = NodeHeader(0, 1)
    h2 = NodeHeader(1, 2)
    x1 = Terminal(b, 0)
    x2 = Terminal(b, 0)
    println(x1)
end

@testset "MDD2" begin
    b = MDDForest()
    h1 = NodeHeader(0, 1)
    h2 = NodeHeader(1, 2)
    x1 = Terminal(b, 0)
    x2 = Terminal(b, 0)
    n = Node(b, h1, AbstractNode[x1, x2])
    println(n)
end

@testset "MDD3" begin
    b = MDDForest()
    h1 = NodeHeader(0, 2)
    h2 = NodeHeader(1, 3)
    x1 = Terminal(b, 0)
    x2 = Terminal(b, 1)
    n1 = Node(b, h1, AbstractNode[x1, x2])
    n2 = Node(b, h2, AbstractNode[n1, x2, x2])
    println(todot(b, n2))
end

@testset "MDD4" begin
    b = MDDForest()
    h1 = NodeHeader(0, 3)
    h2 = NodeHeader(1, 3)
    h3 = NodeHeader(2, 2)
    x1 = Terminal(b, 0)
    x2 = Terminal(b, 1)
    x3 = Terminal(b, 2)
    x4 = Terminal(b, 3)

    n1 = Node(b, h3, AbstractNode[x1, x2])
    n2 = Node(b, h2, AbstractNode[x1, x2, x2])
    n3 = Node(b, h1, AbstractNode[x1, x2, x2])
    tmp1 = apply!(b, MDDMin(), n1, n2)
    tmp2 = apply!(b, MDDMin(), n1, n3)
    v1 = apply!(b, MDDMax(), tmp1, tmp2)
    println(todot(b, v1))

    n1 = Node(b, h3, AbstractNode[x1, x3])
    n2 = Node(b, h2, AbstractNode[x1, x3, x3])
    n3 = Node(b, h1, AbstractNode[x1, x3, x3])
    v2 = apply!(b, MDDMin(), apply!(b, MDDMin(), n1, n2), n3)
    println(todot(b, v2))

    n1 = Node(b, h3, AbstractNode[x1, x4])
    n21 = Node(b, h2, AbstractNode[x1, x1, x4])
    n22 = Node(b, h2, AbstractNode[x1, x4, x4])
    n31 = Node(b, h1, AbstractNode[x1, x1, x4])
    n32 = Node(b, h1, AbstractNode[x1, x4, x4])
    tmp1 = apply!(b, MDDMin(), apply!(b, MDDMin(), n1, n21), n32)
    tmp2 = apply!(b, MDDMin(), apply!(b, MDDMin(), n1, n22), n31)
    v3 = apply!(b, MDDMax(), tmp1, tmp2)
    println(todot(b, v3))

    v = apply!(b, MDDMax(), apply!(b, MDDMax(), v1, v2), v3)
    println(todot(b, v))
end

@testset "MDD5" begin
    b = mdd()
    x = var!(b, :x, 1, 0:5)
    y = var!(b, :y, 2, 0:2)
    z = !(1 + x > 3)
    println(todot(z))
end

@testset "MDD6" begin
    b = mdd()
    x = var!(b, :x, 1, 0:10)
    y = var!(b, :y, 2, 0:10)
    z = var!(b, :z, 3, 0:10)
    a = and!(b, x > 5, or!(b, y <= 3, z != 6))
    println(todot(a))
end

@testset "MDD7" begin
    b = mdd()
    x = var!(b, :x, 1, 0:1)
    y = var!(b, :y, 2, 0:1)
    z = var!(b, :z, 3, 0:1)
    a = x + y + z == 1
    println(todot(a))
end

@testset "MDD8" begin
    b = mdd()
    x = var!(b, :x, 1, 0:1)
    y = var!(b, :y, 2, 0:1)
    z = var!(b, :z, 3, 0:1)
    a = 5*x + 8*y - 2*z >=4
    println(todot(a))
end

@testset "MDD9" begin
    b = mdd()
    x = var!(b, :x, 1, 0:10)
    y = var!(b, :y, 2, 0:10)
    z = var!(b, :z, 3, 0:10)
    a = and(x > 5, y <= 3, z != 6)
    println(todot(a))
end

@testset "MDD10" begin
    b = mdd()
    x = var!(b, :x, 1, 0:2)
    y = var!(b, :y, 2, 0:2)
    z = var!(b, :z, 3, 0:2)
    a = max(x + y, z)
    println(todot(a))
    a = min(x + y, z)
    println(todot(a))
end

@testset "MDD11" begin
    b = mdd()
    x = var!(b, :x, 1, 0:2)
    y = var!(b, :y, 2, 0:2)
    z = var!(b, :z, 3, 0:2)
    a = ifelse(x + y >= 1, y, 1)
    println(todot(a))
end

@testset "MDD12" begin
    b = mdd()
    x = var!(b, :x, 1, 0:2)
    y = var!(b, :y, 2, 0:2)
    z = var!(b, :z, 3, 0:2)
    a = ifelse(x + y >= 1, z, nothing)
    println(todot(a))
end
