import DD.MDD: MDDForest, NodeHeader, Terminal, Node, AbstractNode, todot, binapply!, MDDMin, MDDMax
import DD.MDD: MSSVariable, MSS, gte!, lte!, eq!, neq!, ifelse!, and!, or!

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
    tmp1 = binapply!(b, b.minop, n1, n2)
    tmp2 = binapply!(b, b.minop, n1, n3)
    v1 = binapply!(b, b.maxop, tmp1, tmp2)
    println(todot(b, v1))

    n1 = Node(b, h3, AbstractNode[x1, x3])
    n2 = Node(b, h2, AbstractNode[x1, x3, x3])
    n3 = Node(b, h1, AbstractNode[x1, x3, x3])
    v2 = binapply!(b, b.minop, binapply!(b, b.minop, n1, n2), n3)
    println(todot(b, v2))

    n1 = Node(b, h3, AbstractNode[x1, x4])
    n21 = Node(b, h2, AbstractNode[x1, x1, x4])
    n22 = Node(b, h2, AbstractNode[x1, x4, x4])
    n31 = Node(b, h1, AbstractNode[x1, x1, x4])
    n32 = Node(b, h1, AbstractNode[x1, x4, x4])
    tmp1 = binapply!(b, b.minop, binapply!(b, b.minop, n1, n21), n32)
    tmp2 = binapply!(b, b.minop, binapply!(b, b.minop, n1, n22), n31)
    v3 = binapply!(b, b.maxop, tmp1, tmp2)
    println(todot(b, v3))

    v = binapply!(b, b.maxop, binapply!(b, b.maxop, v1, v2), v3)
    println(todot(b, v))
end

@testset "MSS1" begin
    x1 = MSSVariable(:x1, [0,1])
    x2 = MSSVariable(:x2, [0,1,2])
    x3 = MSSVariable(:x3, [0,1,2])

    mss = MSS([x1, x2, x3], [0,1,2,3])
    # Node(mss.dd, mss.headers[:x1], mss.valuesAbstractNode[x1, x3])

    println(mss)
    println(mss.dd)
end

@testset "MSS2" begin
    x1 = MSSVariable(:x1, [0,1])
    x2 = MSSVariable(:x2, [0,1,2])
    x3 = MSSVariable(:x3, [0,1,2])

    mss = MSS([x1, x2, x3], [0,1,2,3])
    x = gte!(mss, :x1, 0)
    println(todot(mss.dd, x))
end

@testset "MSS3" begin
    x1 = MSSVariable(:x1, [0,1])
    x2 = MSSVariable(:x2, [0,1,2])
    x3 = MSSVariable(:x3, [0,1,2])

    mss = MSS([x1, x2, x3], [0,1,2,3])
    x = gte!(mss, :x1, 1)
    x = ifelse!(mss, x, mss.terminals[2], mss.terminals[3])
    println(todot(mss.dd, x))
end

@testset "MSS4" begin
    x1 = MSSVariable(:x1, [0,1])
    x2 = MSSVariable(:x2, [0,1,2])
    x3 = MSSVariable(:x3, [0,1,2])

    mss = MSS([x3, x2, x1], [0,1,2,3])
    cond0 = or!(mss, eq!(mss, :x1, 0), and!(mss, eq!(mss, :x2, 0), eq!(mss, :x3, 0))) # x1 == 0 || (x2 == 0 && x3 == 0)
    cond1 = and!(mss, eq!(mss, :x1, 1), or!(mss, eq!(mss, :x2, 0), eq!(mss, :x3, 0))) # x1 == 1 && (x2 == 0 || x3 == 0)
    cond3 = and!(mss, eq!(mss, :x1, 1), or!(mss, eq!(mss, :x2, 2), eq!(mss, :x3, 2))) # x1 == 1 && (x2 == 2 || x3 == 2)
    x = ifelse!(mss, cond0, mss.terminals[0], ifelse!(mss, cond1, mss.terminals[1], ifelse!(mss, cond3, mss.terminals[3], mss.terminals[2])))
    println(todot(mss.dd, x))
end

@testset "MSS5" begin
    x1 = MSSVariable(:x1, [0,1])
    x2 = MSSVariable(:x2, [0,1,2])
    x3 = MSSVariable(:x3, [0,1,2])

    mss = MSS([x3, x2, x1], [0,1,2,3])
    cond0 = and!(mss, eq!(mss, :x2, 0), eq!(mss, :x3, 0)) # x2 == 0 && x3 == 0
    cond1 = or!(mss, eq!(mss, :x2, 0), eq!(mss, :x3, 0)) # x2 == 0 || x3 == 0
    cond3 = or!(mss, eq!(mss, :x2, 2), eq!(mss, :x3, 2)) # x2 == 2 || x3 == 2
    x = ifelse!(mss, eq!(mss, :x1, 0), mss.terminals[0],
        ifelse!(mss, cond0, mss.terminals[0],
        ifelse!(mss, cond1, mss.terminals[1],
        ifelse!(mss, cond3, mss.terminals[3],
        mss.terminals[2]))))
    println(todot(mss.dd, x))
end