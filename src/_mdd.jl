"""
MDD Module
"""

module MDD

import Base
#export bdd, header!, var!, node!, not, and, or, xor, imp, ite, todot

export
    lt!,
    lte!,
    gt!,
    gte!,
    eq!,
    neq!,
    plus!,
    minus!,
    mul!,
    max!,
    min!,
    and,
    or,
    and!,
    or!,
    not!,
    todot,
    ifelse!,
    ifelse,
    @match,
    mdd

"""
AbstractNode{Ts}

An abstract node for BDD. The parameter Ts represents a type for a symbol of variable.
Ts is usually Symbol.
"""

abstract type AbstractNode end
abstract type AbstractTerminal <: AbstractNode end

function Base.show(io::IO, n::AbstractNode)
    Base.show(io, "node$(n.id)")
end

"""
type alias
"""

struct Undetermined end

const NodeID = UInt
const LevelT = Int
const ValueT = Int

abstract type AbstractOperator end

struct MDDMin <: AbstractOperator end
struct MDDMax <: AbstractOperator end

struct MDDPlus <: AbstractOperator end
struct MDDMinus <: AbstractOperator end
struct MDDMul <: AbstractOperator end

struct MDDLte <: AbstractOperator end
struct MDDLt <: AbstractOperator end
struct MDDGte <: AbstractOperator end
struct MDDGt <: AbstractOperator end
struct MDDEq <: AbstractOperator end
struct MDDNeq <: AbstractOperator end

struct MDDAnd <: AbstractOperator end
struct MDDOr <: AbstractOperator end
struct MDDNot <: AbstractOperator end

struct MDDIf <: AbstractOperator end
struct MDDElse <: AbstractOperator end
struct MDDUnion <: AbstractOperator end

mutable struct NodeManager
    nextid::NodeID
end

function _get_next!(mgr::NodeManager)::NodeID
    id = mgr.nextid
    mgr.nextid += 1
    id
end

"""
Forest

A structure to store the information on DD.

Todo: Get rid of `mutable` (export `totalnodeid` to BDDNodeManager?)
"""

mutable struct MDDForest
    mgr::NodeManager
    hmgr::NodeManager
    utable::Dict{Tuple{NodeID,Vector{NodeID}},AbstractNode}
    vtable::Dict{ValueT,AbstractNode}
    zero::AbstractTerminal
    one::AbstractTerminal
    undetermined::AbstractTerminal
    cache::Dict{Tuple{AbstractOperator,NodeID,NodeID},AbstractNode}

    function MDDForest()
        b = new()
        b.mgr = NodeManager(0)
        b.hmgr = NodeManager(0)
        b.utable = Dict{Tuple{NodeID,Vector{NodeID}},AbstractNode}()
        b.vtable = Dict{ValueT,AbstractNode}()
        b.zero = Terminal{Bool}(b, _get_next!(b.mgr), false)
        b.one = Terminal{Bool}(b, _get_next!(b.mgr), true)
        b.undetermined = Terminal{Undetermined}(b, _get_next!(b.mgr), Undetermined())
        b.cache = Dict{Tuple{AbstractOperator,NodeID,NodeID},AbstractNode}()
        b
    end
end

"""
struct
"""

mutable struct NodeHeader
    id::NodeID
    level::LevelT
    label::Symbol
    domains::Vector{ValueT}
    index::Dict{ValueT,Int}

    function NodeHeader(level::LevelT, domain::ValueT)
        NodeHeader(NodeID(level), level, Symbol(level), [i for i = 1:domain])
    end

    function NodeHeader(id::NodeID, level::LevelT, label::Symbol, domains::Vector{ValueT})
        new(id, level, label, domains, Dict([x => i for (i,x) = enumerate(domains)]...))
    end
end

mutable struct Node <: AbstractNode
    b::MDDForest
    id::NodeID
    header::NodeHeader
    nodes::Vector{AbstractNode}

    function Node(b::MDDForest, h::NodeHeader, nodes::Vector{AbstractNode})
        if _issame(nodes)
            return nodes[1]
        end
        key = (h.id, [x.id for x = nodes])
        get(b.utable, key) do
            id = _get_next!(b.mgr)
            b.utable[key] = new(b, id, h, nodes)
        end
    end
end

function _issame(nodes::Vector{AbstractNode})
    # assume length(nodes) >= 2
    tmp = nodes[1]
    for x = nodes[2:end]
        if tmp.id != x.id
            return false
        end
    end
    return true
end

struct Terminal{Tv} <: AbstractTerminal
    b::MDDForest
    id::NodeID
    value::Tv
end

function Terminal(b::MDDForest, value::ValueT)
    get(b.vtable, value) do
        id = _get_next!(b.mgr)
        b.vtable[value] = Terminal{ValueT}(b, id, value)
    end
end

function Terminal(b::MDDForest, value::Bool)
    if value == true
        b.one
    else
        b.zero
    end
end

function Terminal(b::MDDForest, value::Nothing)
    b.undetermined
end

function getdd(f::AbstractNode)
    f.b
end

Base.issetequal(x::AbstractNode, y::AbstractNode) = x.id == y.id

"""
uniapply

Apply operation for unioperator
"""

function apply!(b::MDDForest, op::AbstractOperator, f::AbstractNode)
    return _apply!(b, op, f)
end

function _apply!(b::MDDForest, op::AbstractOperator, f::Node)
    key = (op, f.id, b.zero.id)
    get(b.cache, key) do
        nodes = AbstractNode[_apply!(b, op, f.nodes[i]) for i = eachindex(f.header.domains)]
        ans = Node(b, f.header, nodes)
        b.cache[key] = ans
    end
end

function _apply!(b::MDDForest, ::MDDNot, f::Terminal{Bool})
    Terminal(b, !f.value)
end

"""
apply

Apply operation for binoperator
"""

function apply!(b::MDDForest, op::AbstractOperator, f::AbstractNode, g::AbstractNode)
    return _apply!(b, op, f, g)
end

function _apply!(b::MDDForest, op::AbstractOperator, f::Node, g::Node)
    key = (op, f.id, g.id)
    get(b.cache, key) do
        if f.header.level > g.header.level
            nodes = AbstractNode[_apply!(b, op, f.nodes[i], g) for i = eachindex(f.header.domains)]
            ans = Node(b, f.header, nodes)
        elseif f.header.level < g.header.level
            nodes = AbstractNode[_apply!(b, op, f, g.nodes[i]) for i = eachindex(g.header.domains)]
            ans = Node(b, g.header, nodes)
        else
            nodes = AbstractNode[_apply!(b, op, f.nodes[i], g.nodes[i]) for i = eachindex(f.header.domains)]
            ans = Node(b, f.header, nodes)
        end
        b.cache[key] = ans
    end
end

function _apply!(b::MDDForest, op::AbstractOperator, f::AbstractTerminal, g::Node)
    key = (op, f.id, g.id)
    get(b.cache, key) do
        nodes = AbstractNode[_apply!(b, op, f, g.nodes[i]) for i = eachindex(g.header.domains)]
        ans = Node(b, g.header, nodes)
        b.cache[key] = ans
    end
end

function _apply!(b::MDDForest, op::AbstractOperator, f::Node, g::AbstractTerminal)
    key = (op, f.id, g.id)
    get(b.cache, key) do
        nodes = AbstractNode[_apply!(b, op, f.nodes[i], g) for i = eachindex(f.header.domains)]
        ans = Node(b, f.header, nodes)
        b.cache[key] = ans
    end
end

for op = [:MDDMin, :MDDMax, :MDDPlus, :MDDMinus, :MDDMul, :MDDLte, :MDDLt, :MDDGte, :MDDGt, :MDDEq, :MDDNeq]
    @eval function _apply!(b::MDDForest, ::$op, ::Terminal{ValueT}, ::Terminal{Undetermined})
        b.undetermined
    end
    @eval function _apply!(b::MDDForest, ::$op, ::Terminal{Undetermined}, ::Terminal{ValueT})
        b.undetermined
    end
    @eval function _apply!(b::MDDForest, ::$op, ::Terminal{Undetermined}, ::Terminal{Undetermined})
        b.undetermined
    end
end

for op = [:MDDAnd, :MDDOr]
    @eval function _apply!(b::MDDForest, ::$op, ::Terminal{Bool}, ::Terminal{Undetermined})
        b.undetermined
    end
    @eval function _apply!(b::MDDForest, ::$op, ::Terminal{Undetermined}, ::Terminal{Bool})
        b.undetermined
    end
    @eval function _apply!(b::MDDForest, ::$op, ::Terminal{Bool}, ::Terminal{Undetermined})
        b.undetermined
    end
    @eval function _apply!(b::MDDForest, ::$op, ::Terminal{Undetermined}, ::Terminal{Undetermined})
        b.undetermined
    end
end

## min

function _apply!(b::MDDForest, ::MDDMin, f::Terminal{ValueT}, g::Terminal{ValueT})
    Terminal(b, min(f.value, g.value))
end

## max

function _apply!(b::MDDForest, ::MDDMax, f::Terminal{ValueT}, g::Terminal{ValueT})
    Terminal(b, max(f.value, g.value))
end

## Plus

function _apply!(b::MDDForest, ::MDDPlus, f::Terminal{ValueT}, g::Terminal{ValueT})
    Terminal(b, f.value + g.value)
end

## Minus

function _apply!(b::MDDForest, ::MDDMinus, f::Terminal{ValueT}, g::Terminal{ValueT})
    Terminal(b, f.value - g.value)
end

## Mul

function _apply!(b::MDDForest, ::MDDMul, f::Terminal{ValueT}, g::Terminal{ValueT})
    Terminal(b, f.value * g.value)
end

## Lte

function _apply!(b::MDDForest, ::MDDLte, f::Terminal{ValueT}, g::Terminal{ValueT})
    Terminal(b, f.value <= g.value)
end

## Lt

function _apply!(b::MDDForest, ::MDDLt, f::Terminal{ValueT}, g::Terminal{ValueT})
    Terminal(b, f.value < g.value)
end

## Gte

function _apply!(b::MDDForest, ::MDDGte, f::Terminal{ValueT}, g::Terminal{ValueT})
    Terminal(b, f.value >= g.value)
end

## Gt

function _apply!(b::MDDForest, ::MDDGt, f::Terminal{ValueT}, g::Terminal{ValueT})
    Terminal(b, f.value > g.value)
end

## Eq

function _apply!(b::MDDForest, ::MDDEq, f::Terminal{ValueT}, g::Terminal{ValueT})
    Terminal(b, f.value == g.value)
end

## Neq

function _apply!(b::MDDForest, ::MDDNeq, f::Terminal{ValueT}, g::Terminal{ValueT})
    Terminal(b, f.value != g.value)
end

## and

# function _apply!(b::MDDForest, ::MDDAnd, f::Terminal{Bool}, g::Node)
#     # assume f.value, g.value are bool
#     if f.value == true
#         g
#     else
#         b.zero
#     end
# end

# function _apply!(b::MDDForest, ::MDDAnd, f::Node, g::Terminal{Bool})
#     # assume f.value, g.value are bool
#     if g.value == true
#         f
#     else
#         b.zero
#     end
# end

function _apply!(b::MDDForest, ::MDDAnd, f::Terminal{Bool}, g::Terminal{Bool})
    # assume f.value, g.value are bool
    Terminal(b, f.value && g.value)
end

## or

# function _apply!(b::MDDForest, ::MDDOr, f::Terminal{Bool}, g::Node)
#     # assume f.value, g.value are bool
#     if f.value == false
#         g
#     else
#         b.one
#     end
# end

# function _apply!(b::MDDForest, ::MDDOr, f::Node, g::Terminal{Bool})
#     # assume f.value, g.value are bool
#     if g.value == false
#         f
#     else
#         b.one
#     end
# end

function _apply!(b::MDDForest, ::MDDOr, f::Terminal{Bool}, g::Terminal{Bool})
    # assume f.value, g.value are bool
    Terminal(b, f.value || g.value)
end

####### if

function _apply!(b::MDDForest, ::MDDIf, f::Terminal{Bool}, g::Terminal{Tx}) where Tx <: Union{ValueT, Bool, Undetermined}
    # assume f.value is bool, g.value is integer
    if f.value == true
        g
    else
        b.undetermined
    end
end

function _apply!(b::MDDForest, ::MDDIf, f::Terminal{Undetermined}, g::AbstractTerminal)
    b.undetermined
end

## else

function _apply!(b::MDDForest, ::MDDElse, f::Terminal{Bool}, g::Terminal{Tx}) where Tx <: Union{ValueT, Bool, Undetermined}
    # assume f.value is bool, g.value is integer
    if f.value == false
        g
    else
        b.undetermined
    end
end

function _apply!(b::MDDForest, ::MDDElse, f::Terminal{Undetermined}, g::AbstractTerminal)
    b.undetermined
end

## Union

function _apply!(b::MDDForest, ::MDDUnion, f::Terminal{Undetermined}, g::Terminal{Tx}) where Tx <: Union{ValueT, Bool}
    g
end

function _apply!(b::MDDForest, ::MDDUnion, f::Terminal{Tx}, g::Terminal{Undetermined}) where Tx <: Union{ValueT, Bool}
    f
end

function _apply!(b::MDDForest, ::MDDUnion, f::Terminal{Tx}, g::Terminal{Ty}) where {Tx <: Union{ValueT, Bool}, Ty <: Union{ValueT, Bool}}
    throw(ErrorException("There exists a conflict condition."))
end

function _apply!(b::MDDForest, ::MDDUnion, f::Terminal{Undetermined}, g::Terminal{Undetermined})
    b.undetermined
end

"""
todot(forest, f)
Return a string for dot to draw a diagram.
"""

function todot(b::MDDForest, f::AbstractNode)
    io = IOBuffer()
    visited = Set{NodeID}()
    println(io, "digraph { layout=dot; overlap=false; splines=true; node [fontsize=10];")
    _todot!(b, f, visited, io)
    println(io, "}")
    String(take!(io))
end

function _todot!(b::MDDForest, f::AbstractTerminal, visited::Set{NodeID}, io::IO)
    if in(f.id, visited)
        return
    end
    println(io, "\"obj$(f.id)\" [shape = square, label = \"$(f.value)\"];")
    push!(visited, f.id)
    nothing
end

function _todot!(b::MDDForest, f::Node, visited::Set{NodeID}, io::IO)
    if in(f.id, visited)
        return
    end
    println(io, "\"obj$(f.id)\" [shape = circle, label = \"$(f.header.label)\"];")
    for (i,x) = enumerate(f.header.domains)
        if f.nodes[i].id != b.undetermined.id
            _todot!(b, f.nodes[i], visited, io)
            println(io, "\"obj$(f.id)\" -> \"obj$(f.nodes[i].id)\" [label = \"$(x)\"];")
        end
    end
    push!(visited, f.id)
    nothing
end

### utilities

mdd() = MDDForest()

function var!(b::MDDForest, name::Symbol, level::LevelT, domains::AbstractVector{ValueT})
    h = NodeHeader(_get_next!(b.hmgr), level, name, collect(domains))
    Node(b, h, AbstractNode[Terminal(b, x) for x = domains])
end

lt!(b::MDDForest, f::AbstractNode, g::AbstractNode) = apply!(b, MDDLt(), f, g)
lte!(b::MDDForest, f::AbstractNode, g::AbstractNode) = apply!(b, MDDLte(), f, g)
gt!(b::MDDForest, f::AbstractNode, g::AbstractNode) = apply!(b, MDDGt(), f, g)
gte!(b::MDDForest, f::AbstractNode, g::AbstractNode) = apply!(b, MDDGte(), f, g)
eq!(b::MDDForest, f::AbstractNode, g::AbstractNode) = apply!(b, MDDEq(), f, g)
neq!(b::MDDForest, f::AbstractNode, g::AbstractNode) = apply!(b, MDDNeq(), f, g)

function and!(b::MDDForest, x::AbstractNode, xs...)
    tmp = x
    for u = xs
        tmp = apply!(b, MDDAnd(), tmp, u)
    end
    tmp
end

function or!(b::MDDForest, x::AbstractNode, xs...)
    tmp = x
    for u = xs
        tmp = apply!(b, MDDOr(), tmp, u)
    end
    tmp
end

function and(x::AbstractNode, xs...)
    b = getdd(x)
    and!(b, x, xs...)
end

function or(x::AbstractNode, xs...)
    b = getdd(x)
    or!(b, x, xs...)
end

not!(b::MDDForest, f::AbstractNode) = apply!(b, MDDNot(), f)

function ifelse!(b::MDDForest, f::AbstractNode, g::AbstractNode, h::AbstractNode)
    tmp1 = apply!(b, MDDIf(), f, g)
    tmp2 = apply!(b, MDDElse(), f, h)
    apply!(b, MDDUnion(), tmp1, tmp2)
end

function ifelse(f::AbstractNode, g::AbstractNode, h::AbstractNode)
    b = getdd(f)
    ifelse!(b, f, g, h)
end

function ifelse(f::AbstractNode, g::Tx, h::AbstractNode) where Tx <: Union{ValueT,Nothing}
    b = getdd(f)
    ifelse!(b, f, Terminal(b, g), h)
end

function ifelse(f::AbstractNode, g::AbstractNode, h::Tx) where Tx <: Union{ValueT,Nothing}
    b = getdd(f)
    ifelse!(b, f, g, Terminal(b, h))
end

function ifelse(f::AbstractNode, g::Tx1, h::Tx2) where {Tx1 <: Union{ValueT,Nothing}, Tx2 <: Union{ValueT,Nothing}}
    b = getdd(f)
    ifelse!(b, f, Terminal(b, g), Terminal(b, h))
end

function ifelse(f::Bool, g::AbstractNode, h::AbstractNode)
    b = getdd(g)
    ifelse!(b, Terminal(b, f), g, h)
end

function ifelse(f::Bool, g::Tx, h::AbstractNode) where Tx <: Union{ValueT,Nothing}
    b = getdd(h)
    ifelse!(b, Terminal(b, f), Terminal(b, g), h)
end

function ifelse(f::Bool, g::AbstractNode, h::Tx) where Tx <: Union{ValueT,Nothing}
    b = getdd(g)
    ifelse!(b, Terminal(b, f), g, Terminal(b, h))
end

function ifelse(f::Bool, g::Tx1, h::Tx2) where {Tx1 <: Union{ValueT,Nothing}, Tx2 <: Union{ValueT,Nothing}}
    if f
        g
    else
        h
    end
end

# function match!(b::MDDForest, args::Vararg{Tuple{AbstractNode,AbstractNode}})
#     tmp = default
#     for x = reverse(args)
#         tmp = ifelse!(x[1], x[2], tmp)
#     end
#     tmp
# end

function max!(b::MDDForest, x::AbstractNode, xs...)
    tmp = x
    for u = xs
        tmp = apply!(b, MDDMax(), tmp, u)
    end
    tmp
end

function min!(b::MDDForest, x::AbstractNode, xs...)
    tmp = x
    for u = xs
        tmp = apply!(b, MDDMin(), tmp, u)
    end
    tmp
end

function plus!(b::MDDForest, x::AbstractNode, xs...)
    tmp = x
    for u = xs
        tmp = apply!(b, MDDPlus(), tmp, u)
    end
    tmp
end

minus!(b::MDDForest, f::AbstractNode, g::AbstractNode) = apply!(b, MDDMinus(), f, g)

function mul!(b::MDDForest, x::AbstractNode, xs...)
    tmp = x
    for u = xs
        tmp = apply!(b, MDDMul(), tmp, u)
    end
    tmp
end

ops = [:(<), :(<=), :(>), :(>=), :(==), :(!=), :(+), :(-), :(*), :(max), :(min)]
fns = [:lt!, :lte!, :gt!, :gte!, :eq!, :neq!, :plus!, :minus!, :mul!, :max!, :min!]

for (op, fn) = zip(ops, fns)
    @eval Base.$op(x::AbstractNode, y::AbstractNode) = $fn(getdd(x), x, y)
    @eval Base.$op(x::AbstractNode, y::ValueT) = $fn(getdd(x), x, Terminal(getdd(x), y))
    @eval Base.$op(x::ValueT, y::AbstractNode) = $fn(getdd(y), Terminal(getdd(y), x), y)
    @eval Base.$op(x::AbstractNode, y::Bool) = $fn(getdd(x), x, Terminal(getdd(x), y))
    @eval Base.$op(x::Bool, y::AbstractNode) = $fn(getdd(y), Terminal(getdd(y), x), y)
    @eval Base.$op(x::AbstractNode, y::Nothing) = $fn(getdd(x), x, Terminal(getdd(x)))
    @eval Base.$op(x::Nothing, y::AbstractNode) = $fn(getdd(y), Terminal(getdd(y)), y)
end

# ops = [:and, :or]
# fns = [:and!, :or!]

# for (op, fn) = zip(ops, fns)
#     @eval $op(x::AbstractNode, xs...) = $fn(getdd(x), x, xs)
#     @eval $op(x::AbstractNode, y::Bool) = $fn(getdd(x), x, Terminal(getdd(x), y))
#     @eval $op(x::Bool, y::AbstractNode) = $fn(getdd(y), Terminal(getdd(y), x), y)
#     @eval $op(x::AbstractNode, y::Nothing) = $fn(getdd(x), x, Terminal(getdd(x)))
#     @eval $op(x::Nothing, y::AbstractNode) = $fn(getdd(y), Terminal(getdd(y)), y)
# end

Base.:(!)(x::AbstractNode) = not!(getdd(x), x)
Base.:(-)(x::AbstractNode) = minus!(getdd(x), Terminal(getdd(x), 0), x)
todot(f::AbstractNode) = todot(getdd(f), f)

"""
macro
    @match

usage

    z = @match(
        x + y => x,
        _ => 1
        )

"""

function _cond(s::Any)
    s
end

function _cond(x::Expr)
    if Meta.isexpr(x, :(&&))
        Expr(:call, :and, [_cond(u) for u = x.args]...)
    elseif Meta.isexpr(x, :(||))
        Expr(:call, :or, [_cond(u) for u = x.args]...)
    else
        x
    end
end

function _match(v)
    if length(v) > 1
        x = v[1]
        if Meta.isexpr(x, :call) && x.args[1] == :(=>)
            Expr(:call, :ifelse, _cond(x.args[2]), _cond(x.args[3]), _match(v[2:end]))
        else
            throw(ErrorException("Format error"))
        end
    else
        x = v[1]
        if Meta.isexpr(x, :call) && x.args[1] == :(=>) && x.args[2] == :(_)
            _cond(x.args[3])
        elseif Meta.isexpr(x, :call) && x.args[1] == :(=>)
            Expr(:call, :ifelse, _cond(x.args[2]), _cond(x.args[3]), :nothing)
        else
            throw(ErrorException("Format error"))
        end
    end
end

macro match(xs...)
    esc(_match(xs))
end

end
