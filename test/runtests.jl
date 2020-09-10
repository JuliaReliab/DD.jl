using DD
using Test

@testset "DDtest1" begin
    forest = BDDForest{Int,Int,Int}(FullyReduced())
    defval!(forest, 0)
    defval!(forest, 1)
    defvar!(forest, :x, 3, domain(0:1))
    defvar!(forest, :y, 2, domain(0:1))
    defvar!(forest, :z, 1, domain(0:1))
    vars = bddvars!(forest, 0, 1)
    f1 = bddand!(forest, vars[:x], vars[:y])
    f2 = bddor!(forest, vars[:x], vars[:y])
    f3 = bddite!(forest, vars[:x], vars[:y], vars[:z])
    @test vars[:x].nodes[1] == ddval!(forest, 0)
    @test vars[:x].nodes[2] == ddval!(forest, 1)
    @test vars[:y].nodes[1] == ddval!(forest, 0)
    @test vars[:y].nodes[2] == ddval!(forest, 1)
    @test vars[:z].nodes[1] == ddval!(forest, 0)
    @test vars[:z].nodes[2] == ddval!(forest, 1)
    @test f1.nodes[2].nodes[2] == ddval!(forest, 1)
    @test f1.nodes[2].nodes[1] == ddval!(forest, 0)
    @test f1.nodes[1] == ddval!(forest, 0)
    @test f2.nodes[1].nodes[1] == ddval!(forest, 0)
    @test f2.nodes[1].nodes[2] == ddval!(forest, 1)
    @test f2.nodes[2] == ddval!(forest, 1)
end

@testset "DDtest2" begin
    # ddview is deleted
    # @test DD.PydotPlus != PyCall.PyPtr_NULL
    forest = BDDForest{Int,Int,Int}(FullyReduced())
    defval!(forest, 0)
    defval!(forest, 1)
    defvar!(forest, :x, 3, domain(0:1))
    defvar!(forest, :y, 2, domain(0:1))
    defvar!(forest, :z, 1, domain(0:1))
    vars = bddvars!(forest, 0, 1)
    # ddview is deleted to ensure the running environment
    # ddview(forest, vars[:x])
    # ddview(forest, vars[:y])
    # ddview(forest, vars[:z])
    f1 = bddand!(forest, vars[:x], vars[:y])
    f2 = bddor!(forest, vars[:x], vars[:y])
    f3 = bddite!(forest, vars[:x], vars[:y], vars[:z])
    # ddview is deleted to ensure the running environment
    # ddview(forest, f1)
    # ddview(forest, f2)
    # ddview(forest, f3)
end
