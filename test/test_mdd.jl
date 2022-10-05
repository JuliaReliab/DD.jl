import DD.MDD: MDDForest, NodeHeader, Terminal, Node, AbstractNode, todot, apply!, MDDMin, MDDMax
import DD.MDD: MSSVariable, MSS, var!, val!, gte!, lte!, eq!, neq!, ifelse!, and!, or!, max!, min!, @mss

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

@testset "MSS1" begin
    mss = MSS()
    x1 = var!(mss, :x1, [0,1])
    x2 = var!(mss, :x2, [0,1,2])
    x3 = var!(mss, :x3, [0,1,2])

    println(mss)
    println(mss.dd)
end

@testset "MSS2" begin
    mss = MSS()
    x1 = var!(mss, :x1, [0,1])
    x2 = var!(mss, :x2, [0,1,2])
    x3 = var!(mss, :x3, [0,1,2])

    x = gte!(mss.dd, x2, val!(mss, 1))
    println(todot(mss.dd, x))
end

@testset "MSS3" begin
    mss = MSS()
    x1 = var!(mss, :x1, [0,1])
    x2 = var!(mss, :x2, [0,1,2])
    x3 = var!(mss, :x3, [0,1,2])

    x = gte!(mss.dd, x1, val!(mss, 1))
    x = ifelse!(mss.dd, x, val!(mss, 2), val!(mss, 3))
    println(todot(mss.dd, x))
end

@testset "MSS4" begin
    mss = MSS()
    x1 = var!(mss, :x1, [0,1])
    x2 = var!(mss, :x2, [0,1,2])
    x3 = var!(mss, :x3, [0,1,2])

    b = mss.dd
    cond0 = or!(b, eq!(b, x1, val!(b, 0)), and!(b, eq!(b, x2, val!(b, 0)), eq!(b, x3, val!(b, 0)))) # x1 == 0 || (x2 == 0 && x3 == 0)
    cond1 = and!(b, eq!(b, x1, val!(b, 1)), or!(b, eq!(b, x2, val!(b, 0)), eq!(b, x3, val!(b, 0)))) # x1 == 1 && (x2 == 0 || x3 == 0)
    cond3 = and!(b, eq!(b, x1, val!(b, 1)), or!(b, eq!(b, x2, val!(b, 2)), eq!(b, x3, val!(b, 2)))) # x1 == 1 && (x2 == 2 || x3 == 2)
    x = ifelse!(b, cond0, val!(b, 0), ifelse!(b, cond1, val!(b, 1), ifelse!(b, cond3, val!(b, 3), val!(b, 2))))
    println(todot(b, x))
end

@testset "MSS5" begin
    mss = MSS()
    x1 = var!(mss, :x1, [0,1])
    x2 = var!(mss, :x2, [0,1,2])
    x3 = var!(mss, :x3, [0,1,2])

    b = mss.dd
    cond0 = and!(b, eq!(b, x2, val!(b, 0)), eq!(b, x3, val!(b, 0))) # x2 == 0 && x3 == 0
    cond1 = or!(b, eq!(b, x2, val!(b, 0)), eq!(b, x3, val!(b, 0))) # x2 == 0 || x3 == 0
    cond3 = or!(b, eq!(b, x2, val!(b, 2)), eq!(b, x3, val!(b, 2))) # x2 == 2 || x3 == 2
    x = ifelse!(b, eq!(b, x1, val!(b, 0)), val!(b, 0),
        ifelse!(b, cond0, val!(b, 0),
        ifelse!(b, cond1, val!(b, 1),
        ifelse!(b, cond3, val!(b, 3),
        val!(b, 2)))))
    println(todot(b, x))
end

@testset "MSS6" begin
    mss = MSS()
    x1 = var!(mss, :x1, [0,1])
    x2 = var!(mss, :x2, [0,1,2])
    x3 = var!(mss, :x3, [0,1,2])

    x = @macroexpand @mss mss.dd begin
        x1 == 0 => 0
        x2 == 0 && x3 == 0 => 0
        x2 == 0 || x3 == 0 => 1
        x2 == 2 || x3 == 2 => 3
        _ => 2
    end
    println(x)
end

@testset "MSS6" begin
    mss = MSS()
    x3 = var!(mss, :x3, [0,1,2])
    x2 = var!(mss, :x2, [0,1,2])
    x1 = var!(mss, :x1, [0,1])

    x = @mss mss.dd begin
        x1 == 0 => 0
        x2 == 0 && x3 == 0 => 0
        x2 == 0 || x3 == 0 => 1
        x2 == 2 || x3 == 2 => 3
        _ => 2
    end
    println(todot(mss.dd, x))
end

@testset "MSS7" begin
    mss = MSS()
    x3 = var!(mss, :x3, [0,1,2])
    x2 = var!(mss, :x2, [0,1,2])
    x1 = var!(mss, :x1, [0,1])

    x = @mss mss.dd begin
        x1 == 0 => 0
        x2 == 0 && x3 == 0 => 0
        x2 == 0 || x3 == 0 => 1
        x2 == 2 || x3 == 2 => 3
        _ => 2
    end

    y = @mss mss.dd begin
        x == 0 || x2 == 1 => 100
        x2 == 2 => 200
        _ => 1
    end
    println(todot(mss.dd, y))
end

@testset "MSS8" begin
    mss = MSS()
    x1 = var!(mss, :x1, [0,1])
    x2 = var!(mss, :x2, [0,1])
    x3 = var!(mss, :x3, [0,1,2])

    s1 = @mss mss.dd begin
        x1 == 1 || x2 == 1 => 1
        _ => 0
    end

    s2 = @mss mss.dd begin
        x2 == 0 && x3 == 0 => 0
        x2 == 0 => 1
        x3 == 2 => 2
        _ => 0
    end

    s3 = min!(mss.dd, s1, s2)
    println(todot(mss.dd, s1))
    println(todot(mss.dd, s2))
    println(todot(mss.dd, s3))
end

@testset "MSS9" begin
    mss = MSS()
    C = var!(mss, :C, [0,1,2])
    B = var!(mss, :B, [0,1,2])
    A = var!(mss, :A, [0,1])

    Sx = @mss mss.dd begin
        B == 0 && C == 0 => 0
        B == 0 || C == 0 => 1
        B == 2 || C == 2 => 3
        _ => 2
    end

    SS = @mss mss.dd begin
        A == 0 => 0
        _ => Sx
    end

    println(todot(mss.dd, SS))
end
