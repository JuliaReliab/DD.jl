import DD.MDD: MDDForest, NodeHeader, Terminal, Node, AbstractNode, todot, apply!, MDDMin, MDDMax
import DD.MDD: MSSVariable, MSS, var!, val!, gte!, lt!, gt!, lte!, eq!, neq!, ifelse!, and!, or!, max!, min!, plus!, minus!, mul!, prob, @mss, ValueT
import DD.MDD: MDDIf, MDDElse

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
    x1 = var!(mss, :x1, ValueT[0,1])
    x2 = var!(mss, :x2, ValueT[0,1,2])
    x3 = var!(mss, :x3, ValueT[0,1,2])

    println(mss)
    println(mss.dd)
end

@testset "MSS2" begin
    mss = MSS()
    x1 = var!(mss, :x1, ValueT[0,1])
    x2 = var!(mss, :x2, ValueT[0,1,2])
    x3 = var!(mss, :x3, ValueT[0,1,2])

    x = gte!(mss.dd, x2, val!(mss, 1))
    println(todot(mss.dd, x))
end

@testset "MSS3" begin
    mss = MSS()
    x1 = var!(mss, :x1, ValueT[0,1])
    x2 = var!(mss, :x2, ValueT[0,1,2])
    x3 = var!(mss, :x3, ValueT[0,1,2])

    x = gte!(mss.dd, x1, val!(mss, 1))
    x = ifelse!(mss.dd, x, val!(mss, 2), val!(mss, 3))
    println(todot(mss.dd, x))
end

@testset "MSS4" begin
    mss = MSS()
    x1 = var!(mss, :x1, ValueT[0,1])
    x2 = var!(mss, :x2, ValueT[0,1,2])
    x3 = var!(mss, :x3, ValueT[0,1,2])

    b = mss.dd
    cond0 = or!(b, eq!(b, x1, Terminal(b, 0)), and!(b, eq!(b, x2, Terminal(b, 0)), eq!(b, x3, Terminal(b, 0)))) # x1 == 0 || (x2 == 0 && x3 == 0)
    cond1 = and!(b, eq!(b, x1, Terminal(b, 1)), or!(b, eq!(b, x2, Terminal(b, 0)), eq!(b, x3, Terminal(b, 0)))) # x1 == 1 && (x2 == 0 || x3 == 0)
    cond3 = and!(b, eq!(b, x1, Terminal(b, 1)), or!(b, eq!(b, x2, Terminal(b, 2)), eq!(b, x3, Terminal(b, 2)))) # x1 == 1 && (x2 == 2 || x3 == 2)
    x = ifelse!(b, cond0, Terminal(b, 0), ifelse!(b, cond1, Terminal(b, 1), ifelse!(b, cond3, Terminal(b, 3), Terminal(b, 2))))
    println(todot(b, x))
end

@testset "MSS5" begin
    mss = MSS()
    x1 = var!(mss, :x1, ValueT[0,1])
    x2 = var!(mss, :x2, ValueT[0,1,2])
    x3 = var!(mss, :x3, ValueT[0,1,2])

    b = mss.dd
    cond0 = and!(b, eq!(b, x2, Terminal(b, 0)), eq!(b, x3, Terminal(b, 0))) # x2 == 0 && x3 == 0
    cond1 = or!(b, eq!(b, x2, Terminal(b, 0)), eq!(b, x3, Terminal(b, 0))) # x2 == 0 || x3 == 0
    cond3 = or!(b, eq!(b, x2, Terminal(b, 2)), eq!(b, x3, Terminal(b, 2))) # x2 == 2 || x3 == 2
    x = ifelse!(b, eq!(b, x1, Terminal(b, 0)), Terminal(b, 0),
        ifelse!(b, cond0, Terminal(b, 0),
        ifelse!(b, cond1, Terminal(b, 1),
        ifelse!(b, cond3, Terminal(b, 3),
        Terminal(b, 2)))))
    println(todot(b, x))
end

@testset "MSS6" begin
    mss = MSS()
    x1 = var!(mss, :x1, ValueT[0,1])
    x2 = var!(mss, :x2, ValueT[0,1,2])
    x3 = var!(mss, :x3, ValueT[0,1,2])

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
    x3 = var!(mss, :x3, ValueT[0,1,2])
    x2 = var!(mss, :x2, ValueT[0,1,2])
    x1 = var!(mss, :x1, ValueT[0,1])

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
    x3 = var!(mss, :x3, ValueT[0,1,2])
    x2 = var!(mss, :x2, ValueT[0,1,2])
    x1 = var!(mss, :x1, ValueT[0,1])

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
    x1 = var!(mss, :x1, ValueT[0,1])
    x2 = var!(mss, :x2, ValueT[0,1])
    x3 = var!(mss, :x3, ValueT[0,1,2])

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
    C = var!(mss, :C, ValueT[0,1,2])
    B = var!(mss, :B, ValueT[0,1,2])
    A = var!(mss, :A, ValueT[0,1])

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

@testset "MSS10" begin
    mss = MSS()
    C = var!(mss, :C, ValueT[0,1,2])
    B = var!(mss, :B, ValueT[0,1,2])
    A = var!(mss, :A, ValueT[0,1])

    p = Dict([
        A.header=>[0.2, 0.8],
        B.header=>[0.2, 0.2, 0.6],
        C.header=>[0.1, 0.3, 0.6]
    ])

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

    println([prob(mss.dd, SS, p, v) for v = [0,1,2,3]])
end

@testset "MSS11" begin
    mss = MSS()
    x3 = var!(mss, :x3, 0:10)
    x2 = var!(mss, :x2, 0:10)
    x1 = var!(mss, :x1, 0:10)
    t1 = var!(mss, :t1, 0:1)
    t1dash = var!(mss, :t1, 0:1)

    x1dash = @mss mss.dd begin
        t1 == 1 && x1 >= 1 && x2 >= 1 && x3 < 10 => x1 - 1
        _ => x1
    end

    x2dash = @mss mss.dd begin
        t1 == 1 && x1 >= 1 && x2 >= 1 && x3 < 10 => x2 - 1
        _ => x2
    end

    x3dash = @mss mss.dd begin
        t1 == 1 && x1 >= 1 && x2 >= 1 && x3 < 10 => x3 + 1
        _ => x3
    end

    x1dashdash = @mss mss.dd begin
        t1dash == 2 && x1dash >= 1 && x2dash >= 1 && x3dash < 10 => x1dash - 1
        _ => x1dash
    end

    println(todot(mss.dd, x1dashdash))
    # println(todot(mss.dd, x2dash))
    # println(todot(mss.dd, x3dash))
end

@testset "MSS12" begin
    mss = MSS()
    n = 5
    x = [var!(mss, Symbol(:x, i), 0:n) for i = 1:6]
    t = var!(mss, :t, 1:6)

    s = @mss mss.dd begin
        x[2] - x[3] + x[4] - x[5] == 0 => 1
        _ => None
    end

    x1dash = @mss mss.dd begin
        s == 1 && t == 1 && x[1] < 5 => x[1] + 1
        s == 1 && t == 2 && x[1] > 1 && x[2] < 5 && x[3] < 5 => x[1] - 1
        s == 1 => x[1]
        _ => None
    end

    println(todot(mss.dd, x1dash))
end

# @testset "MSS12" begin
#     n = 5
#     mss = MSS()
#     x = [var!(mss, Symbol(:x, i), 0:n) for i = 1:6]
#     t = var!(mss, :t, 1:6)

#     s = @mss mss.dd begin
#         x[2] - x[3] + x[4] - x[5] == 0 => 1
#         _ => 0
#     end

#     x1dash = @mss mss.dd begin
#         s == 1 && t == 1 && x[1] < 5 => x[1] + 1
#         s == 1 && t == 2 && x[1] > 1 && x[2] < 5 && x[3] < 5 => x[1] - 1
#         s == 1 => x[1]
#         _ => None
#     end

#     println(todot(mss.dd, x1dash))

#     x2dash = @mss mss.dd begin
#         s == 1 && t == 2 && x[1] > 1 && x[2] < 5 && x[3] < 5 => x[2] + 1
#         s == 1 && t == 3 && x[2] > 1 && x[4] < 5 => x[2] - 1
#         s == 1 => x[2]
#         _ => None
#     end

#     println(todot(mss.dd, x2dash))

#     x3dash = @mss mss.dd begin
#         s == 1 && t == 2 && x[1] > 1 && x[2] < 5 && x[3] < 5 => x[3] + 1
#         s == 1 && t == 4 && x[3] > 1 && x[5] < 5 => x[3] - 1
#         s == 1 => x[3]
#         _ => None
#     end

#     println(todot(mss.dd, x3dash))

#     x4dash = @mss mss.dd begin
#         s == 1 && t == 3 && x[2] > 1 && x[4] < 5 => x[4] + 1
#         s == 1 && t == 5 && x[4] > 1 && x[5] > 1 && x[6] < 5 => x[4] - 1
#         s == 1 => x[4]
#         _ => None
#     end

#     println(todot(mss.dd, x4dash))

#     x5dash = @mss mss.dd begin
#         s == 1 && t == 4 && x[3] > 1 && x[5] < 5 => x[5] + 1
#         s == 1 && t == 5 && x[4] > 1 && x[5] > 1 && x[6] < 5 => x[5] - 1
#         s == 1 => x[5]
#         _ => None
#     end

#     println(todot(mss.dd, x5dash))

#     x6dash = @mss mss.dd begin
#         s == 1 && t == 5 && x[4] > 1 && x[5] > 1 && x[6] < 5 => x[6] + 1
#         s == 1 && t == 6 && x[6] > 1 => x[6] - 1
#         s == 1 => x[6]
#         _ => None
#     end

#     println(todot(mss.dd, x6dash))

#     xdash = [x1dash, x2dash, x3dash, x4dash, x5dash, x6dash]
#     t1 = var!(mss, :t1, 1:6)

#     x1dash = @mss mss.dd begin
#         t1 == 1 && xdash[1] < 5 => xdash[1] + 1
#         t1 == 2 && xdash[1] > 1 && xdash[2] < 5 && xdash[3] < 5 => xdash[1] - 1
#         _ => xdash[1]
#     end    

#     println(todot(mss.dd, x1dash))
# end
