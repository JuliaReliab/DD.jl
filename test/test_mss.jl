import DD.MDD: MDDForest, NodeHeader, Terminal, Node, AbstractNode, todot, apply!, MDDMin, MDDMax
import DD.MDD: MSSVariable, MSS, var!, val!, gte!, lt!, gt!, lte!, eq!, neq!, ifelse!, and!, or!, max!, min!, plus!, minus!, mul!, prob, @mss, ValueT
import DD.MDD: MDDIf, MDDElse, getbounds, getmaxbounds2, getminbounds2, getbounds2, getbounds3
using Random

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
    nn = Terminal(mss.dd, n)
    x = [var!(mss, Symbol(:x, i), 0:n) for i = 1:6]
    t1 = var!(mss, :t1, 1:6)
    t2 = var!(mss, :t2, 1:6)

    @time begin
        s = @mss mss.dd begin
            x[2] - x[3] + x[4] - x[5] == 0 => 1
            _ => None
        end

        x1dash = @mss mss.dd begin
            s == 1 && t1 == 1 && x[1] < nn => x[1] + 1
            s == 1 && t1 == 2 && x[1] >= 1 && x[2] < nn && x[3] < nn => x[1] - 1
            s == 1 => x[1]
            _ => None
        end

        x2dash = @mss mss.dd begin
            s == 1 && t1 == 2 && x[1] >= 1 && x[2] < nn && x[3] < nn => x[2] + 1
            s == 1 && t1 == 3 && x[2] >= 1 && x[4] < nn => x[2] - 1
            s == 1 => x[2]
            _ => None
        end

        x3dash = @mss mss.dd begin
            s == 1 && t1 == 2 && x[1] >= 1 && x[2] < nn && x[3] < nn => x[3] + 1
            s == 1 && t1 == 4 && x[3] >= 1 && x[5] < nn => x[3] - 1
            s == 1 => x[3]
            _ => None
        end

        x4dash = @mss mss.dd begin
            s == 1 && t1 == 3 && x[2] >= 1 && x[4] < nn => x[4] + 1
            s == 1 && t1 == 5 && x[4] >= 1 && x[5] >= 1 && x[6] < nn => x[4] - 1
            s == 1 => x[4]
            _ => None
        end

        x5dash = @mss mss.dd begin
            s == 1 && t1 == 4 && x[3] >= 1 && x[5] < nn => x[5] + 1
            s == 1 && t1 == 5 && x[4] >= 1 && x[5] >= 1 && x[6] < nn => x[5] - 1
            s == 1 => x[5]
            _ => None
        end

        x6dash = @mss mss.dd begin
            s == 1 && t1 == 5 && x[4] >= 1 && x[5] >= 1 && x[6] < nn => x[6] + 1
            s == 1 && t1 == 6 && x[6] >= 1 => x[6] - 1
            s == 1 => x[6]
            _ => None
        end

        x = [x1dash, x2dash, x3dash, x4dash, x5dash, x6dash]

        x1dash = @mss mss.dd begin
            t2 == 1 && x[1] < nn => x[1] + 1
            t2 == 2 && x[1] >= 1 && x[2] < nn && x[3] < nn => x[1] - 1
            _ => x[1]
        end    

        x2dash = @mss mss.dd begin
            t2 == 2 && x[1] >= 1 && x[2] < nn && x[3] < nn => x[2] + 1
            t2 == 3 && x[2] >= 1 && x[4] < nn => x[2] - 1
            _ => x[2]
        end

        x3dash = @mss mss.dd begin
            t2 == 2 && x[1] >= 1 && x[2] < nn && x[3] < nn => x[3] + 1
            t2 == 4 && x[3] >= 1 && x[5] < nn => x[3] - 1
            _ => x[3]
        end

        x4dash = @mss mss.dd begin
            t2 == 3 && x[2] >= 1 && x[4] < nn => x[4] + 1
            t2 == 5 && x[4] >= 1 && x[5] >= 1 && x[6] < nn => x[4] - 1
            _ => x[4]
        end

        x5dash = @mss mss.dd begin
            t2 == 4 && x[3] >= 1 && x[5] < nn => x[5] + 1
            t2 == 5 && x[4] >= 1 && x[5] >= 1 && x[6] < nn => x[5] - 1
            _ => x[5]
        end

        x6dash = @mss mss.dd begin
            t2 == 5 && x[4] >= 1 && x[5] >= 1 && x[6] < nn => x[6] + 1
            t2 == 6 && x[6] >= 1 => x[6] - 1
            _ => x[6]
        end
    end

    # v = getbounds(mss.dd, x1dash, [0,0,0,0,0,0,6,6], [n,n,n,n,n,n,6,6])
    # println(v)

    rng = MersenneTwister(1234)
    lower = [0, 0, 0, 0, 0, 0]
    upper = [n, n, n, n, n, n]
    @time begin
        event = [rand(rng, 1:6), rand(rng, 1:6)]
        l = cat(lower, event, dims=1)
        u = cat(upper, event, dims=1)
        v1 = getbounds(mss.dd, x1dash, l, u)
        v2 = getbounds(mss.dd, x2dash, l, u)
        v3 = getbounds(mss.dd, x3dash, l, u)
        v4 = getbounds(mss.dd, x4dash, l, u)
        v5 = getbounds(mss.dd, x5dash, l, u)
        v6 = getbounds(mss.dd, x6dash, l, u)
        for (i,x) = enumerate([v1, v2, v3, v4, v5, v6])
            lower[i] = x[1]
            upper[i] = x[2]
        end
        println(lower, upper)
    end
    @time begin
        for k = 1:100
            event = [rand(rng, 1:6),rand(rng, 1:6)]
            l = cat(lower, event, dims=1)
            u = cat(upper, event, dims=1)
            v1 = getbounds(mss.dd, x1dash, l, u)
            v2 = getbounds(mss.dd, x2dash, l, u)
            v3 = getbounds(mss.dd, x3dash, l, u)
            v4 = getbounds(mss.dd, x4dash, l, u)
            v5 = getbounds(mss.dd, x5dash, l, u)
            v6 = getbounds(mss.dd, x6dash, l, u)
            for (i,x) = enumerate([v1, v2, v3, v4, v5, v6])
                lower[i] = x[1]
                upper[i] = x[2]
            end
            println(lower, upper)
        end
    end
end

@testset "MSS13" begin
    mss = MSS()
    n = 50
    nn = Terminal(mss.dd, n)
    x = [var!(mss, Symbol(:x, i), 0:n) for i = 1:6]
    x0 = x
    t1 = var!(mss, :t1, 1:6)
    t2 = var!(mss, :t2, 1:6)

    @time begin
        s = @mss mss.dd begin
            x[2] - x[3] + x[4] - x[5] == 0 => 1
            _ => None
        end

        x1dash = @mss mss.dd begin
            s == 1 && t1 == 1 && x[1] < nn => 1
            s == 1 && t1 == 2 && x[1] >= 1 && x[2] < nn && x[3] < nn => -1
            s == 1 => 0
            _ => None
        end

        x2dash = @mss mss.dd begin
            s == 1 && t1 == 2 && x[1] >= 1 && x[2] < nn && x[3] < nn => 1
            s == 1 && t1 == 3 && x[2] >= 1 && x[4] < nn => -1
            s == 1 => 0
            _ => None
        end

        x3dash = @mss mss.dd begin
            s == 1 && t1 == 2 && x[1] >= 1 && x[2] < nn && x[3] < nn => 1
            s == 1 && t1 == 4 && x[3] >= 1 && x[5] < nn => -1
            s == 1 => 0
            _ => None
        end

        x4dash = @mss mss.dd begin
            s == 1 && t1 == 3 && x[2] >= 1 && x[4] < nn => 1
            s == 1 && t1 == 5 && x[4] >= 1 && x[5] >= 1 && x[6] < nn => -1
            s == 1 => 0
            _ => None
        end

        x5dash = @mss mss.dd begin
            s == 1 && t1 == 4 && x[3] >= 1 && x[5] < nn => 1
            s == 1 && t1 == 5 && x[4] >= 1 && x[5] >= 1 && x[6] < nn => -1
            s == 1 => 0
            _ => None
        end

        x6dash = @mss mss.dd begin
            s == 1 && t1 == 5 && x[4] >= 1 && x[5] >= 1 && x[6] < nn => 1
            s == 1 && t1 == 6 && x[6] >= 1 => -1
            s == 1 => 0
            _ => None
        end

        # x6dash = @mss mss.dd begin
        #     t1 == 5 && x[4] >= 1 && x[5] >= 1 && x[6] < nn => 1
        #     t1 == 6 && x[6] >= 1 => -1
        #     _ => 0
        # end

        # println(todot(mss.dd, x6dash))

        dx = [x1dash, x2dash, x3dash, x4dash, x5dash, x6dash]
        x = [plus!(mss.dd, x[i], dx[i]) for i = 1:6]

        x1dash = @mss mss.dd begin
            t2 == 1 && x[1] < nn => dx[1] + 1
            t2 == 2 && x[1] >= 1 && x[2] < nn && x[3] < nn => dx[1] - 1
            _ => dx[1]
        end    

        x2dash = @mss mss.dd begin
            t2 == 2 && x[1] >= 1 && x[2] < nn && x[3] < nn => dx[2] + 1
            t2 == 3 && x[2] >= 1 && x[4] < nn => dx[2] - 1
            _ => dx[2]
        end

        x3dash = @mss mss.dd begin
            t2 == 2 && x[1] >= 1 && x[2] < nn && x[3] < nn => dx[3] + 1
            t2 == 4 && x[3] >= 1 && x[5] < nn => dx[3] - 1
            _ => dx[3]
        end

        x4dash = @mss mss.dd begin
            t2 == 3 && x[2] >= 1 && x[4] < nn => dx[4] + 1
            t2 == 5 && x[4] >= 1 && x[5] >= 1 && x[6] < nn => dx[4] - 1
            _ => dx[4]
        end

        x5dash = @mss mss.dd begin
            t2 == 4 && x[3] >= 1 && x[5] < nn => dx[5] + 1
            t2 == 5 && x[4] >= 1 && x[5] >= 1 && x[6] < nn => dx[5] - 1
            _ => dx[5]
        end

        x6dash = @mss mss.dd begin
            t2 == 5 && x[4] >= 1 && x[5] >= 1 && x[6] < nn => dx[6] + 1
            t2 == 6 && x[6] >= 1 => dx[6] - 1
            _ => dx[6]
        end
    end

    # println(todot(mss.dd, plus!(mss.dd, x6dash, x0[6])))

    # x1dash =  plus!(mss.dd, x1dash, x0[1])
    # x2dash =  plus!(mss.dd, x2dash, x0[2])
    # x3dash =  plus!(mss.dd, x3dash, x0[3])
    # x4dash =  plus!(mss.dd, x4dash, x0[4])
    # x5dash =  plus!(mss.dd, x5dash, x0[5])
    # x6dash =  plus!(mss.dd, x6dash, x0[6])
    # rng = MersenneTwister(1234)
    # lower = [0, 0, 0, 0, 0, 0]
    # upper = [n, n, n, n, n, n]
    # @time begin
    #     event = [rand(rng, 1:6), rand(rng, 1:6)]
    #     l = cat(lower, event, dims=1)
    #     u = cat(upper, event, dims=1)
    #     v1 = getbounds(mss.dd, x1dash, l, u)
    #     v2 = getbounds(mss.dd, x2dash, l, u)
    #     v3 = getbounds(mss.dd, x3dash, l, u)
    #     v4 = getbounds(mss.dd, x4dash, l, u)
    #     v5 = getbounds(mss.dd, x5dash, l, u)
    #     v6 = getbounds(mss.dd, x6dash, l, u)
    #     for (i,x) = enumerate([v1, v2, v3, v4, v5, v6])
    #         lower[i] = x[1]
    #         upper[i] = x[2]
    #     end
    #     println(lower, upper)
    # end
    # @time begin
    #     for k = 1:1000
    #         event = [rand(rng, 1:6),rand(rng, 1:6)]
    #         l = cat(lower, event, dims=1)
    #         u = cat(upper, event, dims=1)
    #         v1 = getbounds(mss.dd, x1dash, l, u)
    #         v2 = getbounds(mss.dd, x2dash, l, u)
    #         v3 = getbounds(mss.dd, x3dash, l, u)
    #         v4 = getbounds(mss.dd, x4dash, l, u)
    #         v5 = getbounds(mss.dd, x5dash, l, u)
    #         v6 = getbounds(mss.dd, x6dash, l, u)
    #         for (i,x) = enumerate([v1, v2, v3, v4, v5, v6])
    #             lower[i] = x[1]
    #             upper[i] = x[2]
    #         end
    #         println(lower, upper)
    #     end
    # end

    # TODO: getbounds2 is wrong
    # @time begin
    #     v = getbounds3(mss.dd, x6dash, [0,0,0,0,0,0,6,1], [n,n,n,n,n,n,6,1], 6)
    #     println(v)
    # end

    rng = MersenneTwister(1234)
    lower = [0, 0, 0, 0, 0, 0]
    upper = [n, n, n, n, n, n]
    @time begin
        event = [rand(rng, 1:6), rand(rng, 1:6)]
        println(event)
        l = cat(lower, event, dims=1)
        u = cat(upper, event, dims=1)
        v1 = getbounds3(mss.dd, x1dash, l, u, 1)
        v2 = getbounds3(mss.dd, x2dash, l, u, 2)
        v3 = getbounds3(mss.dd, x3dash, l, u, 3)
        v4 = getbounds3(mss.dd, x4dash, l, u, 4)
        v5 = getbounds3(mss.dd, x5dash, l, u, 5)
        v6 = getbounds3(mss.dd, x6dash, l, u, 6)
        for (i,x) = enumerate([v1, v2, v3, v4, v5, v6])
            lower[i] = x[1]
            upper[i] = x[2]
        end
        println(lower, upper)
    end
    @time begin
        for k = 1:100
            event = [rand(rng, 1:6),rand(rng, 1:6)]
            l = cat(lower, event, dims=1)
            u = cat(upper, event, dims=1)
            v1 = getbounds3(mss.dd, x1dash, l, u, 1)
            v2 = getbounds3(mss.dd, x2dash, l, u, 2)
            v3 = getbounds3(mss.dd, x3dash, l, u, 3)
            v4 = getbounds3(mss.dd, x4dash, l, u, 4)
            v5 = getbounds3(mss.dd, x5dash, l, u, 5)
            v6 = getbounds3(mss.dd, x6dash, l, u, 6)
            for (i,x) = enumerate([v1, v2, v3, v4, v5, v6])
                lower[i] = x[1]
                upper[i] = x[2]
            end
            # println(lower, upper)
        end
    end
    println(lower, upper)
end


