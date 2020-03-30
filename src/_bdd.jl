
export BDDForest, bddnot!, bddand!, bddor!, bddite!, bddvars!

"""
BDDForest{Tl} <: AbstractDDForest{Tv,Ti,Tl}

A forest for DD nodes. This takes the following fields.
- vals::Dict{Tv,DDValue} A dictionary for defined values
- vars::Dict{Symbol,Tuple{DDLevel,DDDomain}} A dictionary for defined variables
- varcache: A cache to ensure the node identification in the forest.
- opcache: A cache for the results
- policy::AbstractDDPolicy An instance of singlton to reduce the nodes.
"""

struct BDDForest{Tv,Ti,Tl} <: AbstractDDForest{Tv,Ti,Tl}
    vals::Dict{Tv,DDValue{Tv,Ti}}
    vars::Dict{Symbol,Tuple{Tl,DDDomain{Ti}}}
    varcache::Dict{DDKey{Tv,Ti},AbstractDDNode{Tv,Ti}}
    opcache::Dict{DDOPKey{Tv,Ti},AbstractDDNode{Tv,Ti}}
    policy::AbstractDDPolicy

    function BDDForest{Tv,Ti,Tl}(policy) where {Tv,Ti,Tl}
        vals = Dict{Tv,DDValue{Tv,Ti}}()
        vars = Dict{Symbol,Tuple{Tl,DDDomain{Ti}}}()
        varcache = Dict{DDKey{Tv,Ti},AbstractDDNode{Tv,Ti}}()
        opcache = Dict{DDOPKey{Tv,Ti},AbstractDDNode{Tv,Ti}}()
        new(vals, vars, varcache, opcache, policy)
    end
end

"""
_ddreduce(forest, label, nodes)

Apply the reduction policy
"""

function _ddreduce(forest::BDDForest{Tv,Ti,Tl},
        label::Symbol,
        nodes::NTuple{2,AbstractDDNode{Tv,Ti}})::AbstractDDNode{Tv,Ti} where {Tv,Ti,Tl}
    if nodes[1] == nodes[2]
        nodes[1]
    else
        DDVariable{Tv,Ti,2}(label, nodes...)
    end
end

"""
BDD
"""

struct _NotBDDOperator <: AbstractUnaryDDOperator end
struct _AndBDDOperator <: AbstractBinaryDDOperator end
struct _OrBDDOperator <: AbstractBinaryDDOperator end


"""
functions for values
"""

_fistrue(x::Bool) = x
_fisfalse(x::Tv) where Tv = !_fistrue(x)

_fnot(x::Bool) = !x
_fand(x::Bool, y::Bool) = x && y
_for(x::Bool, y::Bool) = x || y

_fistrue(x::Int) = x == 1
_fnot(x::Int) = _fistrue(x) ? 0 : 1
_fand(x::Int, y::Int) = _fand(_fistrue(x), _fistrue(y)) ? 1 : 0
_for(x::Int, y::Int) = _for(_fistrue(x), _fistrue(y)) ? 1 : 0

"""
Not
"""

function _apply!(::AbstractDDPolicy,
        forest::BDDForest{Tv,Ti,Tl},
        op::_NotBDDOperator,
        f::DDValue{Tv,Ti}) where {Tv,Ti,Tl}
    ddval!(forest, _fnot(f.val))
end

"""
And
"""

function _apply!(::AbstractDDPolicy,
        forest::BDDForest{Tv,Ti,Tl},
        op::_AndBDDOperator,
        f::DDValue{Tv,Ti},
        g::DDValue{Tv,Ti}) where {Tv,Ti,Tl}
    ddval!(forest, _fand(f.val, g.val))
end

function _apply!(::FullyReduced,
        forest::BDDForest{Tv,Ti,Tl},
        op::_AndBDDOperator,
        f::DDValue{Tv,Ti},
        g::DDVariable{Tv,Ti}) where {Tv,Ti,Tl}
    if _fisfalse(f.val)
        ddval!(forest, f.val)
    else
        g
    end
end

function _apply!(::FullyReduced,
        forest::BDDForest{Tv,Ti,Tl},
        op::_AndBDDOperator,
        f::DDVariable{Tv,Ti},
        g::DDValue{Tv,Ti}) where {Tv,Ti,Tl}
    if _fisfalse(g.val)
        ddval!(forest, g.val)
    else
        f
    end
end

"""
OR
"""

function _apply!(::AbstractDDPolicy,
        forest::BDDForest{Tv,Ti,Tl},
        op::_OrBDDOperator,
        f::DDValue{Tv,Ti},
        g::DDValue{Tv,Ti}) where {Tv,Ti,Tl}
    ddval!(forest, _for(f.val, g.val))
end

function _apply!(::FullyReduced,
        forest::BDDForest{Tv,Ti,Tl},
        op::_OrBDDOperator,
        f::DDValue{Tv,Ti},
        g::DDVariable{Tv,Ti}) where {Tv,Ti,Tl}
    if _fistrue(f.val)
        ddval!(forest, f.val)
    else
        g
    end
end

function _apply!(::FullyReduced,
        forest::BDDForest{Tv,Ti,Tl},
        op::_OrBDDOperator,
        f::DDVariable{Tv,Ti},
        g::DDValue{Tv,Ti}) where {Tv,Ti,Tl}
    if _fistrue(g.val)
        ddval!(forest, g.val)
    else
        f
    end
end

"""
bddnot!(forest::BDDForest{Tv,Ti,Tl}, f::DDVariable{Tv,Ti})

Return a varibale of not(f). The result is chached in the forest.
"""

function bddnot!(forest::BDDForest{Tv,Ti,Tl},
        f::DDVariable{Tv,Ti}) where {Tv,Ti,Tl}
    apply!(forest, _NotBDDOperator(), f)
end

"""
bddand!(forest::BDDForest{Tv,Ti,Tl}, f::DDVariable{Tv,Ti}, g::DDVariable{Tv,Ti})

Return a varibale of and(f,g). The result is chached in the forest.
"""

function bddand!(forest::BDDForest{Tv,Ti,Tl},
        f::AbstractDDNode{Tv,Ti},
        g::AbstractDDNode{Tv,Ti}) where {Tv,Ti,Tl}
    apply!(forest, _AndBDDOperator(), f, g)
end

"""
bddor!(forest::BDDForest{Tv,Ti,Tl}, f::DDVariable{Tv,Ti}, g::DDVariable{Tv,Ti})

Return a varibale of or(f,g). The result is chached in the forest.
"""

function bddor!(forest::BDDForest{Tv,Ti,Tl},
        f::AbstractDDNode{Tv,Ti},
        g::AbstractDDNode{Tv,Ti}) where {Tv,Ti,Tl}
    apply!(forest, _OrBDDOperator(), f, g)
end

"""
bddite!(forest::BDDForest{Tv,Ti,Tl}, f::DDVariable{Tv,Ti}, g::DDVariable{Tv,Ti}, h::DDVariable{Tv,Ti})

Return a varibale of if f then g else h. The result is chached in the forest.
"""

function bddite!(forest::BDDForest{Tv,Ti,Tl},
        f::AbstractDDNode{Tv,Ti},
        g::AbstractDDNode{Tv,Ti},
        h::AbstractDDNode{Tv,Ti}) where {Tv,Ti,Tl}
    bddor!(forest, bddand!(forest, f, g), bddand!(forest, bddnot!(forest, f), h))
end

"""
_getsorted(forest)

Return a vecor of all the symbols in the forest. They are ordered by their levels.
"""

function _getsorted(forest::BDDForest{Tv,Ti,Tl}) where {Tv,Ti,Tl}
    map(x->x[2], sort(map(x->(x[2][1], x[1]), collect(forest.vars)), by=x->x[1]))
end

"""
bddvars!(forest)

Create a dictionary of variables. The key is a symbol. The first and second values correspond to
the high and low of domain. Please see the following example

forest = DD.BDDForest{Int,Int,Int}(DD.FullyReduced())
DD.defval!(forest, 0)
DD.defval!(forest, 1)
DD.defvar!(forest, :x, 3, DD.domain(0:1)) # <- the order of variable is 0, 1
DD.defvar!(forest, :y, 2, DD.domain(0:1)) # <- the order of variable is 0, 1
DD.defvar!(forest, :z, 1, DD.domain(0:1)) # <- the order of variable is 0, 1
vars = DD.bddvars!(forest, 0, 1)          # <- the order of value is 0, 1
DD.view(forest, vars[:x])
DD.view(forest, vars[:y])
DD.view(forest, vars[:z])
f1 = DD.bddand!(forest, vars[:x], vars[:y])
f2 = DD.bddor!(forest, vars[:x], vars[:y])
f3 = DD.bddite!(forest, vars[:x], vars[:y], vars[:z])
DD.view(forest, f1)
DD.view(forest, f2)
DD.view(forest, f3)
"""

function bddvars!(forest::BDDForest{Tv,Ti,Tl}, firstvalue::Tv, secondvalue::Tv) where {Tv,Ti,Tl}
    t = ddval!(forest, firstvalue)
    f = ddval!(forest, secondvalue)
    v = Dict{Symbol,AbstractDDNode{Tv,Ti}}()
    sorted = _getsorted(forest)
    for s1 in sorted
        for s2 in sorted
            s1 == s2 && break
            v[s2] = ddvar!(forest, s1, v[s2], v[s2])
        end
        v[s1] = ddvar!(forest, s1, t, f)
        t = ddvar!(forest, s1, t, t)
        f = ddvar!(forest, s1, f, f)
    end
    return v
end

