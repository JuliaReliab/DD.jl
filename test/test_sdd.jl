module SDDTest

using DD.SDD: VtreeVarNode, VtreeNode, Forest, getvars, _var!, _element!, _node!, make_vtree, @vtree, NodeManager, todot, findheader, _apply!, not
using DD.SDD: AndOperator, OrOperator
using Test

# import DD.SDD: SDDForest, NodeHeader, Terminal, Node, AbstractNode, todot, apply!, SDDMin, SDDMax
# import DD.SDD: var!, gte!, lt!, gt!, lte!, eq!, neq!, ifthenelse!, and!, or!, max!, min!, plus!, minus!, mul!, ValueT
# import DD.SDD: SDDIf, SDDElse, sdd, and, or, ifthenelse, @match

# @testset "SDD1" begin
#     x = VtreeVarNode(1,:x)
#     y = VtreeVarNode(2,:y)
#     z = VtreeVarNode(2,:z)
#     v1 = VtreeNode(UInt(4), x, y)
#     v2 = VtreeNode(UInt(5), v1, z)
#     b = Forest(v2)
#     n1 = _var!(b, x, true)
#     n2 = _var!(b, x, false)
#     n3 = _var!(b, y, true)
#     e1 = _element!(b, n1, n3)
#     e2 = _element!(b, n2, b.T)
#     n4 = _node!(b, v1, [e1, e2])
#     println(n4.id)
# end

@testset "SDD2" begin
    expr = :(x < y < z)
    v = make_vtree(expr, NodeManager(1))
    println(todot(v))
end   

@testset "SDD3" begin
    expr = :(x > y > z)
    v = make_vtree(expr, NodeManager(1))
    println(todot(v))
end   

@testset "SDD4" begin
    expr = :((x < y) < (z < v))
    v = make_vtree(expr, NodeManager(1))
    println(todot(v))
end   

@testset "SDD5" begin
    v = @vtree x < y < z
    println(todot(v))
end   

@testset "SDD6" begin
    v = @vtree (x < y) < z
    b = Forest(v)
    println(b.headers)
end   

@testset "SDD1" begin
    v = @vtree (x < y) < z
    b = Forest(v)
    n1 = b.vars[:x]
    n2 = not(b.vars[:x])
    n3 = b.vars[:y]
    e1 = _element!(b, n1, n3)
    e2 = _element!(b, n2, b.T)
    h = findheader(b, n1.header, n3.header)
    println(h)
    n4 = _node!(b, h, [e1, e2])
    # # println(n4.id)
    println(todot(n4))
end

@testset "SDD7" begin
    v = @vtree (x < y) < z
    b = Forest(v)
    x = b.vars[:x]
    y = b.vars[:y]
    z = b.vars[:z]
    n = _apply!(b, AndOperator(), x, y, cache=b.cache)
    n = _apply!(b, AndOperator(), n, z, cache=b.cache)
    println(todot(n))
end

@testset "SDD8" begin
    v = @vtree (B < A) < (D < C)
    println(todot(v))
    b = Forest(v)
    va = b.vars[:A]
    vb = b.vars[:B]
    vc = b.vars[:C]
    vd = b.vars[:D]
    n1 = _apply!(b, AndOperator(), va, vb, cache=b.cache)
    n2 = _apply!(b, AndOperator(), vb, vc, cache=b.cache)
    n3 = _apply!(b, AndOperator(), vc, vd, cache=b.cache)

    n4 = _apply!(b, OrOperator(), n1, n2, cache=b.cache)
    n5 = _apply!(b, OrOperator(), n4, n3, cache=b.cache)
    println(todot(n5))
end

@testset "SDD9" begin
    v = @vtree (A < B) < (C < D)
    println(todot(v))
    b = Forest(v)
    va = b.vars[:A]
    vb = b.vars[:B]
    vc = b.vars[:C]
    vd = b.vars[:D]
    n5 = (va & vb) | (vb & vc) | (vc & vd)
    println(todot(n5))
end

@testset "SDD9" begin
    v = @vtree (((A < B) < C) < D)
    println(todot(v))
    b = Forest(v)
    va = b.vars[:A]
    vb = b.vars[:B]
    vc = b.vars[:C]
    vd = b.vars[:D]
    n5 = (va & vb) | (vb & vc) | (vc & vd)
    println(todot(n5))
end

end

