module EVMDDTest

using DD.MDD
using DD.EVMDD
using Test

@testset "EVMDD1" begin
    b = mdd()
    n = 10
    for i = 1:6
        MDD.defvar!(b, Symbol(:x, i), i, 0:n)
    end
    MDD.defvar!(b, :t1, 7, 1:6)
    MDD.defvar!(b, :t2, 8, 1:6)
    
    x = [var!(b, Symbol(:x, i)) for i = 1:6]
    t1 = var!(b, :t1)
    t2 = var!(b, :t2)
    
    @time begin
        s = @match(
            x[2] - x[3] + x[4] - x[5] == 0 => 1,
            _ => nothing)
    
        x1dash = @match(
            s == 1 && t1 == 1 && x[1] < n => x[1] + 1,
            s == 1 && t1 == 2 && x[1] >= 1 && x[2] < n && x[3] < n => x[1] - 1,
            s == 1 => x[1],
            _ => nothing)
    
        x2dash = @match(
            s == 1 && t1 == 2 && x[1] >= 1 && x[2] < n && x[3] < n => x[2] + 1,
            s == 1 && t1 == 3 && x[2] >= 1 && x[4] < n => x[2] - 1,
            s == 1 => x[2],
            _ => nothing)
    
        x3dash = @match(
            s == 1 && t1 == 2 && x[1] >= 1 && x[2] < n && x[3] < n => x[3] + 1,
            s == 1 && t1 == 4 && x[3] >= 1 && x[5] < n => x[3] - 1,
            s == 1 => x[3],
            _ => nothing)
    
        x4dash = @match(
            s == 1 && t1 == 3 && x[2] >= 1 && x[4] < n => x[4] + 1,
            s == 1 && t1 == 5 && x[4] >= 1 && x[5] >= 1 && x[6] < n => x[4] - 1,
            s == 1 => x[4],
            _ => nothing)
    
        x5dash = @match(
            s == 1 && t1 == 4 && x[3] >= 1 && x[5] < n => x[5] + 1,
            s == 1 && t1 == 5 && x[4] >= 1 && x[5] >= 1 && x[6] < n => x[5] - 1,
            s == 1 => x[5],
            _ => nothing)
    
        x6dash = @match(
            s == 1 && t1 == 5 && x[4] >= 1 && x[5] >= 1 && x[6] < n => x[6] + 1,
            s == 1 && t1 == 6 && x[6] >= 1 => x[6] - 1,
            s == 1 => x[6],
            _ => nothing)
    
        # x = [x1dash, x2dash, x3dash, x4dash, x5dash, x6dash]
    
        # x1dash = @match(
        #     t2 == 1 && x[1] < n => x[1] + 1,
        #     t2 == 2 && x[1] >= 1 && x[2] < n && x[3] < n => x[1] - 1,
        #     _ => x[1])
    
        # x2dash = @match(
        #     t2 == 2 && x[1] >= 1 && x[2] < n && x[3] < n => x[2] + 1,
        #     t2 == 3 && x[2] >= 1 && x[4] < n => x[2] - 1,
        #     _ => x[2])
    
        # x3dash = @match(
        #     t2 == 2 && x[1] >= 1 && x[2] < n && x[3] < n => x[3] + 1,
        #     t2 == 4 && x[3] >= 1 && x[5] < n => x[3] - 1,
        #     _ => x[3])
    
        # x4dash = @match(
        #     t2 == 3 && x[2] >= 1 && x[4] < n => x[4] + 1,
        #     t2 == 5 && x[4] >= 1 && x[5] >= 1 && x[6] < n => x[4] - 1,
        #     _ => x[4])
    
        # x5dash = @match(
        #     t2 == 4 && x[3] >= 1 && x[5] < n => x[5] + 1,
        #     t2 == 5 && x[4] >= 1 && x[5] >= 1 && x[6] < n => x[5] - 1,
        #     _ => x[5])
    
        # x6dash = @match(
        #     t2 == 5 && x[4] >= 1 && x[5] >= 1 && x[6] < n => x[6] + 1,
        #     t2 == 6 && x[6] >= 1 => x[6] - 1,
        #     _ => x[6])
    end

    x = x6dash
    println(MDD.size(x))
    f0 = mdd2evmdd(x) # return an edge
    println(EVMDD.size(f0))
end

end
