"""
MDD Module
"""

module MDD

export AbstractNode
export AbstractNonTerminalNode
export AbstractTerminalNode
export NodeID
export Level
export FullyReduced
export QuasiReduced

export mdd
export vars
export forest
export get_nodes
export id
export level
export label
export domain
export node!
export value!
export isfalse
export istrue
export isnothing

export defvar!
export var!
export genfunc!

export lt!
export lte!
export gt!
export gte!
export eq!
export neq!
export plus!
export minus!
export mul!
export max!
export min!
export not!
export and!, and
export or!, or
export ifthenelse!, ifthenelse

export todot

export @match

"""
    AbstractNode

Abstract tyoe for BDD node.
"""
abstract type AbstractNode end

"""
    AbstractNonTerminalNode

Abstract type for non-terminal node.
"""
abstract type AbstractNonTerminalNode <: AbstractNode end

"""
    AbstractTerminalNode

Abstract type for terminal node.
"""
abstract type AbstractTerminalNode <: AbstractNode end

function Base.show(io::IO, n::AbstractNode)
    Base.show(io, "node$(n.id)")
end

"""
    NodeID

The identity number for node. This is issued by Forest.
"""
const NodeID = UInt

"""
    Level

The type for node level.
"""
const Level = UInt

"""
    Value

The type for value.
"""
const Value = Int

"""
    AbstractOperator
    AbstractUnaryOperator <: AbstractOperator
    AbstractBinaryOperator <: AbstractOperator
    NotOperator <: AbstractUnaryOperator
    AndOperator <: AbstractBinaryOperator
    OrOperator <: AbstractBinaryOperator
    XorOperator <: AbstractBinaryOperator
    EqOperator <: AbstractBinaryOperator

Types for operations.
- NotOperator: Logical not operation
- AndOperator: Logical and operation
- OrOperator: Logical or operation
- XorOperator: Logical xor operation
- EqOperator: Logical eq operation
"""
abstract type AbstractOperator end
abstract type AbstractUnaryOperator <: AbstractOperator end
abstract type AbstractBinaryOperator <: AbstractOperator end
struct MDDMin <: AbstractBinaryOperator end
struct MDDMax <: AbstractBinaryOperator end
struct MDDPlus <: AbstractBinaryOperator end
struct MDDMinus <: AbstractBinaryOperator end
struct MDDMul <: AbstractBinaryOperator end
struct MDDLte <: AbstractBinaryOperator end
struct MDDLt <: AbstractBinaryOperator end
struct MDDGte <: AbstractBinaryOperator end
struct MDDGt <: AbstractBinaryOperator end
struct MDDEq <: AbstractBinaryOperator end
struct MDDNeq <: AbstractBinaryOperator end
struct MDDAnd <: AbstractBinaryOperator end
struct MDDOr <: AbstractBinaryOperator end
struct MDDNot <: AbstractUnaryOperator end
struct MDDIf <: AbstractBinaryOperator end
struct MDDElse <: AbstractBinaryOperator end
struct MDDUnion <: AbstractBinaryOperator end

"""
    AbstractPolicy
    FullyReduced <: AbstractPolicy
    QuasiReduced <: AbstractPolicy

The types for reduction policy in DD.
- FullyReduced: the node is reduced if all the edges are directed to the same node.
- QuasiReduced: the node is not reduced even if all the edges are directed to the same node.
"""
abstract type AbstractPolicy end
struct FullyReduced <: AbstractPolicy end
struct QuasiReduced <: AbstractPolicy end

"""
    NodeManager

A mutable structure to issue the unique number as ID.
"""
mutable struct NodeManager
    nextid::NodeID
end

"""
    _get_next!(mgr::NodeManager)::NodeID

Issue an ID.
"""
function _get_next!(mgr::NodeManager)::NodeID
    id = mgr.nextid
    mgr.nextid += 1
    id
end

"""
    NodeHeader

A mutable structure indicating the information for nodes in the same level.
- id: Header ID
- level: Level of node. The level of terminal node is 0. 
- label: A symbol to represent the variable
- domain: A vector as the domain of variable
- index: A dictionary to provide the index for a given value.
"""
mutable struct NodeHeader
    id::NodeID
    level::Level
    label::Symbol
    domain::Vector{Value}
    index::Dict{Value,Int}

    # function NodeHeader(level::Level, domain::Value)
    #     new(NodeID(level), level, Symbol(level), [i for i = 1:domain])
    # end

    function NodeHeader(id::NodeID, level::Level, label::Symbol, domain::Vector{Value})
        new(id, level, label, domain, Dict([x => i for (i,x) = enumerate(domain)]...))
    end
end

"""
    Forest

A mutable structure to store the information on DD. The fields are
- mgr: NodeManager to issue IDs of nodes
- hmgr: NodeManager to issue IDs of headers
- headers: A dictionary of the pair of Symbol and NodeHeader
- utable: Unique table to identify the tuple (header id, low node id, high node id)
- zero: A terminal node indicating logical zero
- one: A terminal node indicating logical one
- undet: A terminal node indicating logical undermined value
- cache: A cache for operations
"""
mutable struct Forest
    mgr::NodeManager
    hmgr::NodeManager
    headers::Dict{Symbol,NodeHeader}
    utable::Dict{Tuple{NodeID,Vector{NodeID}},AbstractNode}
    vtable::Dict{Value,AbstractNode}
    zero::AbstractTerminalNode
    one::AbstractTerminalNode
    undet::AbstractTerminalNode
    cache::Dict{Tuple{AbstractOperator,NodeID,NodeID},AbstractNode}
    policy::AbstractPolicy

    function Forest(policy::AbstractPolicy)
        b = new()
        b.mgr = NodeManager(0)
        b.hmgr = NodeManager(0)
        b.headers = Dict{Symbol,NodeHeader}()
        b.utable = Dict{Tuple{NodeID,Vector{NodeID}},AbstractNode}()
        b.vtable = Dict{Value,AbstractNode}()
        b.zero = Terminal{Bool}(b, _get_next!(b.mgr), false)
        b.one = Terminal{Bool}(b, _get_next!(b.mgr), true)
        b.undet = Terminal{Nothing}(b, _get_next!(b.mgr), nothing)
        b.cache = Dict{Tuple{AbstractOperator,NodeID,NodeID},AbstractNode}()
        b.policy = policy
        b
    end
end

function Base.show(io::IO, b::Forest)
    Base.show(io, "Total nodes $(b.mgr.nextid)")
    Base.show(io, "Total headers $(b.hmgr.nextid)")
    Base.show(io, "Length of unique table $(length(b.utable))")
    Base.show(io, "Length of cache $(length(b.cache))")
    Base.show(io, "Policy $(b.policy)")
end

"""
   vars(f)

Return the node hederes
"""
function vars(b::Forest)
    b.headers
end

"""
    Node <: AbstractNonTerminalNode

A structure for a DD node.
- b: The forest that the node belogs to.
- id: Unique ID
- header: An instance of header class
- nodes: Vector of children
"""
mutable struct Node <: AbstractNonTerminalNode
    b::Forest
    id::NodeID
    header::NodeHeader
    nodes::Vector{AbstractNode}
end

"""
    get_nodes(x::AbstractNonTerminalNode)

Get a node vector
"""
function get_nodes(x::AbstractNonTerminalNode)
    x.nodes
end

"""
    id(x::NodeHearder)
    id(x::AbstractNode)

Get an ID
"""
function id(x::NodeHeader)
    x.id
end

function id(x::AbstractNode)
    x.id
end

"""
    level(x::NodeHearder)
    level(x::AbstractNonTerminalNode)
    level(x::AbstractTerminalNode)

Get a level
"""
function level(x::NodeHeader)
    x.level
end

function level(x::AbstractNonTerminalNode)
    x.header.level
end

function level(x::AbstractTerminalNode)
    Level(0)
end

"""
    label(x::NodeHeader)
    label(x::AbstractNonTerminalNode)
    label(x::AbstractTerminalNode)

Get a label
"""
function label(x::NodeHeader)
    x.label
end

function label(x::AbstractNonTerminalNode)
    x.header.label
end

function label(x::AbstractTerminalNode)
    Symbol(x.value)
end

"""
    domain(x::NodeHeader)
    domain(x::AbstractNonTerminalNode)
    domain(x::AbstractTerminalNode)

Get a domain
"""
function domain(x::NodeHeader)
    x.domain
end

function domain(x::AbstractNonTerminalNode)
    x.header.domain
end

# function domain(x::AbstractTerminalNode)
#     b = forest(x)
#     sort(keys(b.vtable))
# end

"""
    node!(b::Forest, h::NodeHeader, nodes::Vector{AbstractNode})

Constructor of Node. If there exists any node which has same children in the same level,
the function returns the exisiting node. In addition, if the policy of forest is the FullyReduced,
the nodes with same directions are reduced.
- b: Forest
- h: NodeHeader
- nodes: A vector of nodes
"""
function node!(b::Forest, h::NodeHeader, nodes::Vector{AbstractNode})
    _node!(b, h, nodes, b.policy)
end

"""
    node!(b::Forest, x::Symbol, nodes::Vector{AbstractNode})

Constructor of Node.
- x: Symbol of variable
- nodes: A vector of nodes
"""
function node!(b::Forest, x::Symbol, nodes::Vector{AbstractNode})
    h = b.headers[x]
    _node!(b, h, nodes, b.policy)
end

function _node!(b::Forest, h::NodeHeader, nodes::Vector{AbstractNode}, ::FullyReduced)
    if _issame(nodes)
        return nodes[1]
    end
    key = (h.id, [x.id for x = nodes])
    get(b.utable, key) do
        id = _get_next!(b.mgr)
        b.utable[key] = Node(b, id, h, nodes)
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

"""
    Terminal{Tv} <: AbstractTerminalNode

A structure of Terminal node.
"""
struct Terminal{Tv} <: AbstractTerminalNode
    b::Forest
    id::NodeID
    value::Tv
end

"""
    value!(b::Forest, value::Value)
    value!(b::Forest, value::Bool)
    value!(b::Forest, value::Nothing)

The constructor of terminal. The value is an integer, boolean or nothing value.
"""
function value!(b::Forest, value::Value)
    get(b.vtable, value) do
        id = _get_next!(b.mgr)
        b.vtable[value] = Terminal{Value}(b, id, value)
    end
end

function value!(b::Forest, value::Bool)
    if value == true
        b.one
    else
        b.zero
    end
end

function value!(b::Forest, ::Nothing)
    b.undet
end

"""
    isfalse(x::AbstractNode)

Return a boolean value if the terminal is false
"""
function isfalse(x::AbstractNonTerminalNode)
    false
end

function isfalse(x::Terminal{Value})
    false
end

function isfalse(x::Terminal{Bool})
    x.value == false
end

function isfalse(x::Terminal{Nothing})
    false
end

"""
    istrue(x::AbstractNode)

Return a boolean value if the terminal is one.
"""
function istrue(x::AbstractNonTerminalNode)
    false
end

function istrue(x::Terminal{Value})
    false
end

function istrue(x::Terminal{Bool})
    x.value == true
end

function istrue(x::Terminal{Nothing})
    false
end

"""
    isnothing(x::AbstractNode)

Return a boolean value if the terminal is one.
"""
function Base.isnothing(x::AbstractNonTerminalNode)
    false
end

function Base.isnothing(x::Terminal{Value})
    false
end

function Base.isnothing(x::Terminal{Bool})
    false
end

function Base.isnothing(x::Terminal{Nothing})
    true
end

"""
   forest(f)

Return the forest of a given node
"""
function forest(f::AbstractNode)
    f.b
end

"""
    apply!(b::Forest, op::AbstractUnaryOperator, f::AbstractNode)
    apply!(b::Forest, op::AbstractBinaryOperator, f::AbstractNode, g::AbstractNode)

Return a node as a result for a given operation.
"""
function apply!(b::Forest, op::AbstractUnaryOperator, f::AbstractNode)
    _apply!(b, op, f)
end

function apply!(b::Forest, op::AbstractBinaryOperator, f::AbstractNode, g::AbstractNode)
    _apply!(b, op, f, g)
end

for t = [:Value, :Bool, :Nothing]
    @eval function apply!(b::Forest, op::AbstractUnaryOperator, f::$t)
        _apply!(b, op, value!(b, f))
    end

    @eval function apply!(b::Forest, op::AbstractBinaryOperator, f::AbstractNode, g::$t)
        _apply!(b, op, f, value!(b, g))
    end

    @eval function apply!(b::Forest, op::AbstractBinaryOperator, f::$t, g::AbstractNode)
        _apply!(b, op, value!(b, f), g)
    end

    @eval function apply!(b::Forest, op::AbstractBinaryOperator, f::$t, g::$t)
        _apply!(b, op, value!(b, f), value!(b, g))
    end
end

function _apply!(b::Forest, op::AbstractUnaryOperator, f::AbstractNonTerminalNode)
    key = (op, f.id, b.zero.id)
    get!(b.cache, key) do
        nodes = AbstractNode[_apply!(b, op, x) for x = f.nodes]
        node!(b, f.header, nodes)
    end
end

function _apply!(b::Forest, op::AbstractBinaryOperator, f::AbstractNonTerminalNode, g::AbstractNonTerminalNode)
    key = (op, f.id, g.id)
    get!(b.cache, key) do
        if f.header.level > g.header.level
            nodes = AbstractNode[_apply!(b, op, x, g) for x = f.nodes]
            node!(b, f.header, nodes)
        elseif f.header.level < g.header.level
            nodes = AbstractNode[_apply!(b, op, f, x) for x = g.nodes]
            node!(b, g.header, nodes)
        else
            nodes = AbstractNode[_apply!(b, op, f.nodes[i], g.nodes[i]) for i = eachindex(f.header.domain)]
            node!(b, f.header, nodes)
        end
    end
end

function _apply!(b::Forest, op::AbstractBinaryOperator, f::AbstractTerminalNode, g::AbstractNonTerminalNode)
    key = (op, f.id, g.id)
    get!(b.cache, key) do
        nodes = AbstractNode[_apply!(b, op, f, x) for x = g.nodes]
        node!(b, g.header, nodes)
    end
end

function _apply!(b::Forest, op::AbstractBinaryOperator, f::AbstractNonTerminalNode, g::AbstractTerminalNode)
    key = (op, f.id, g.id)
    get!(b.cache, key) do
        nodes = AbstractNode[_apply!(b, op, x, g) for x = f.nodes]
        node!(b, f.header, nodes)
    end
end

## Concrete functions

### Logical Not

function _apply!(b::Forest, ::MDDNot, f::Terminal{Bool})
    value!(b, !f.value)
end

### for nothing

for op = [:MDDMin, :MDDMax, :MDDPlus, :MDDMinus, :MDDMul, :MDDLte, :MDDLt, :MDDGte, :MDDGt, :MDDEq, :MDDNeq]
    @eval function _apply!(b::Forest, ::$op, ::Terminal{Value}, ::Terminal{Nothing})
        b.undet
    end
    @eval function _apply!(b::Forest, ::$op, ::Terminal{Nothing}, ::Terminal{Value})
        b.undet
    end
    @eval function _apply!(b::Forest, ::$op, ::Terminal{Nothing}, ::Terminal{Nothing})
        b.undet
    end
end

for op = [:MDDAnd, :MDDOr]
    @eval function _apply!(b::Forest, ::$op, ::Terminal{Bool}, ::Terminal{Nothing})
        b.undet
    end
    @eval function _apply!(b::Forest, ::$op, ::Terminal{Nothing}, ::Terminal{Bool})
        b.undet
    end
    @eval function _apply!(b::Forest, ::$op, ::Terminal{Nothing}, ::Terminal{Nothing})
        b.undet
    end
end

### min

function _apply!(b::Forest, ::MDDMin, f::Terminal{Value}, g::Terminal{Value})
    value!(b, min(f.value, g.value))
end

### max

function _apply!(b::Forest, ::MDDMax, f::Terminal{Value}, g::Terminal{Value})
    value!(b, max(f.value, g.value))
end

### Plus

function _apply!(b::Forest, ::MDDPlus, f::Terminal{Value}, g::Terminal{Value})
    value!(b, f.value + g.value)
end

### Minus

function _apply!(b::Forest, ::MDDMinus, f::Terminal{Value}, g::Terminal{Value})
    value!(b, f.value - g.value)
end

### Mul

function _apply!(b::Forest, ::MDDMul, f::Terminal{Value}, g::Terminal{Value})
    value!(b, f.value * g.value)
end

### Lte

function _apply!(b::Forest, ::MDDLte, f::Terminal{Value}, g::Terminal{Value})
    value!(b, f.value <= g.value)
end

### Lt

function _apply!(b::Forest, ::MDDLt, f::Terminal{Value}, g::Terminal{Value})
    value!(b, f.value < g.value)
end

### Gte

function _apply!(b::Forest, ::MDDGte, f::Terminal{Value}, g::Terminal{Value})
    value!(b, f.value >= g.value)
end

### Gt

function _apply!(b::Forest, ::MDDGt, f::Terminal{Value}, g::Terminal{Value})
    value!(b, f.value > g.value)
end

### Eq

function _apply!(b::Forest, ::MDDEq, f::Terminal{Value}, g::Terminal{Value})
    value!(b, f.value == g.value)
end

function _apply!(b::Forest, ::MDDEq, f::Terminal{Bool}, g::Terminal{Bool})
    value!(b, f.value == g.value)
end

### Neq

function _apply!(b::Forest, ::MDDNeq, f::Terminal{Value}, g::Terminal{Value})
    value!(b, f.value != g.value)
end

function _apply!(b::Forest, ::MDDNeq, f::Terminal{Bool}, g::Terminal{Bool})
    value!(b, f.value != g.value)
end

### and

function _apply!(b::Forest, ::MDDAnd, f::Terminal{Bool}, g::Terminal{Bool})
    value!(b, f.value && g.value)
end

### or

function _apply!(b::Forest, ::MDDOr, f::Terminal{Bool}, g::Terminal{Bool})
    value!(b, f.value || g.value)
end

### if

for v = [:Value, :Bool, :Nothing]
    @eval function _apply!(b::Forest, ::MDDIf, f::Terminal{Bool}, g::Terminal{$v})
        if f.value == true
            g
        else
            b.undet
        end
    end
end

function _apply!(b::Forest, ::MDDIf, f::Terminal{Nothing}, g::AbstractTerminalNode)
    b.undet
end

### else

for v = [:Value, :Bool, :Nothing]
    @eval function _apply!(b::Forest, ::MDDElse, f::Terminal{Bool}, g::Terminal{$v})
        if f.value == false
            g
        else
            b.undet
        end
    end
end

function _apply!(b::Forest, ::MDDElse, f::Terminal{Nothing}, g::AbstractTerminalNode)
    b.undet
end

### Union

for v = [:Value, :Bool]
    @eval function _apply!(::Forest, ::MDDUnion, f::Terminal{Nothing}, g::Terminal{$v})
        g
    end
    
    @eval function _apply!(::Forest, ::MDDUnion, f::Terminal{$v}, g::Terminal{Nothing})
        f
    end
end

function _apply!(b::Forest, ::MDDUnion, f::Terminal{Nothing}, g::Terminal{Nothing})
    b.undet
end

# function _apply!(b::Forest, ::MDDUnion, f::Terminal{Tx}, g::Terminal{Ty}) where {Tx <: Union{Value, Bool}, Ty <: Union{Value, Bool}}
#     throw(ErrorException("There exists a conflict condition."))
# end

"""
    todot(f::AbstractNode)
    todot(b::Forest, f::AbstractNode)

Return a string for dot to draw a diagram.
"""
function todot(f::AbstractNode)
    todot(forest(f), f)
end

function todot(b::Forest, f::AbstractNode)
    io = IOBuffer()
    visited = Set{NodeID}()
    println(io, "digraph { layout=dot; overlap=false; splines=true; node [fontsize=10];")
    _todot!(b, f, visited, io)
    println(io, "}")
    String(take!(io))
end

function _todot!(b::Forest, f::AbstractTerminalNode, visited::Set{NodeID}, io::IO)
    if in(f.id, visited)
        return
    end
    println(io, "\"obj$(f.id)\" [shape = square, label = \"$(f.value)\"];")
    push!(visited, f.id)
    nothing
end

function _todot!(b::Forest, f::Node, visited::Set{NodeID}, io::IO)
    if in(f.id, visited)
        return
    end
    println(io, "\"obj$(f.id)\" [shape = circle, label = \"$(f.header.label)\"];")
    for (i,x) = enumerate(f.header.domain)
        if f.nodes[i].id != b.undet.id
            _todot!(b, f.nodes[i], visited, io)
            println(io, "\"obj$(f.id)\" -> \"obj$(f.nodes[i].id)\" [label = \"$(x)\"];")
        end
    end
    push!(visited, f.id)
    nothing
end

### node and edge

function Base.size(f::AbstractNode)
    b = forest(f)
    visited = Set{NodeID}()
    edges = _size!(b, f, visited)
    (length(visited), edges)
end

function _size!(b::Forest, f::AbstractTerminalNode, visited::Set{NodeID})
    if in(f.id, visited)
        return 0
    end
    push!(visited, f.id)
    return 0
end

function _size!(b::Forest, f::Node, visited::Set{NodeID})
    if in(f.id, visited)
        return 0
    end
    tmp = 0
    for (i,x) = enumerate(f.header.domain)
        if f.nodes[i].id != b.undet.id
            tmp += _size!(b, f.nodes[i], visited)
            tmp += 1
        end
    end
    push!(visited, f.id)
    return tmp
end

### utilities

"""
   mdd(policy::AbstractPolicy = FullyReduced())

Create MDD forest with the reduction policy. Note the policy QuasiReduced has not implemented yet.
"""
mdd(policy::AbstractPolicy = FullyReduced()) = Forest(policy)

"""
    defvar!(b::Forest, name::Symbol, level::Int, domain::AbstractVector{Value})

Define a new variable in MDD
- b: Forest
- name: Symbol of variable
- level: Level in MDD
- domain: Domain of a variable
"""
function defvar!(b::Forest, name::Symbol, level::Int, domain::AbstractVector{Value})
    h = NodeHeader(_get_next!(b.hmgr), Level(level), name, collect(domain))
    b.headers[name] = h
end

"""
    var!(b::Forest, name::Symbol)

Get a node representing that a given variable
- b: Forest
- name: Symbol of variable
"""
function var!(b::Forest, name::Symbol)
    var!(b, name, b.policy)
end

function var!(b::Forest, name::Symbol, ::FullyReduced)
    h = b.headers[name]
    node!(b, h, AbstractNode[value!(b, x) for x = h.domain])
end

"""
    lt!(b::Forest, f, g)

Less than operation
"""
function lt!(b::Forest, f, g)
    apply!(b, MDDLt(), f, g)
end

"""
    lte!(b::Forest, f, g)

Less than or equal to operation
"""
function lte!(b::Forest, f, g)
    apply!(b, MDDLte(), f, g)
end

"""
    gt!(b::Forest, f, g)

Greater than operation
"""
function gt!(b::Forest, f, g)
    apply!(b, MDDGt(), f, g)
end

"""
    gte!(b::Forest, f, g)

Greater than or equal to operation
"""
function gte!(b::Forest, f, g)
    apply!(b, MDDGte(), f, g)
end

"""
    eq!(b::Forest, f, g)

Eq operation
"""
function eq!(b::Forest, f, g)
    apply!(b, MDDEq(), f, g)
end

"""
    neq!(b::Forest, f, g)

Neq operation
"""
function neq!(b::Forest, f, g)
    apply!(b, MDDNeq(), f, g)
end

"""
    and!(b::Forest, x, xs...)

AND operation.
"""
function and!(b::Forest, x, xs...)
    tmp = x
    for u = xs
        tmp = apply!(b, MDDAnd(), tmp, u)
    end
    tmp
end

"""
    or!(b::Forest, x, xs...)

OR operation.
"""
function or!(b::Forest, x, xs...)
    tmp = x
    for u = xs
        tmp = apply!(b, MDDOr(), tmp, u)
    end
    tmp
end

"""
    not!(b::Forest, x::AbstractNode)

NOT operation.
"""
function not!(b::Forest, x)
    apply!(b, MDDNot(), x)
end

"""
    ifthenelse!(b::Forest, f, g, h)
    ifthenelse(f, g, h)

IF-THEN-ELSE operation.
"""
function ifthenelse!(b::Forest, f, g, h)
    tmp1 = apply!(b, MDDIf(), f, g)
    tmp2 = apply!(b, MDDElse(), f, h)
    apply!(b, MDDUnion(), tmp1, tmp2)
end

"""
    max!(b::Forest, x, xs...)

MAX operation.
"""
function max!(b::Forest, x, xs...)
    tmp = x
    for u = xs
        tmp = apply!(b, MDDMax(), tmp, u)
    end
    tmp
end

"""
    min!(b::Forest, x, xs...)

MIN operation.
"""
function min!(b::Forest, x, xs...)
    tmp = x
    for u = xs
        tmp = apply!(b, MDDMin(), tmp, u)
    end
    tmp
end

"""
    plus!(b::Forest, x, xs...)

Plus operation.
"""
function plus!(b::Forest, x, xs...)
    tmp = x
    for u = xs
        tmp = apply!(b, MDDPlus(), tmp, u)
    end
    tmp
end

"""
    minus!(b::Forest, x, y)

Minus operation.
"""
function minus!(b::Forest, f, g)
    apply!(b, MDDMinus(), f, g)
end

"""
    mul!(b::Forest, x, xs...)

Multiple operation.
"""
function mul!(b::Forest, x, xs...)
    tmp = x
    for u = xs
        tmp = apply!(b, MDDMul(), tmp, u)
    end
    tmp
end

### Overloads

and(x::AbstractNode, xs...) = and!(forest(x), x, xs...)
and(x::Bool, y::AbstractNode) = and!(forest(y), x, y)
or(x::AbstractNode, xs...) = or!(forest(x), x, xs...)
or(x::Bool, y::AbstractNode) = or!(forest(y), x, y)
ifthenelse(f::AbstractNode, g::AbstractNode, h::AbstractNode) = ifthenelse!(forest(f), f, g, h)
ifthenelse(f::AbstractNode, g::AbstractNode, h::Any) = ifthenelse!(forest(f), f, g, h)
ifthenelse(f::AbstractNode, g::Any, h::AbstractNode) = ifthenelse!(forest(f), f, g, h)
ifthenelse(f::Any, g::AbstractNode, h::AbstractNode) = ifthenelse!(forest(g), f, g, h)
ifthenelse(f::AbstractNode, g::Any, h::Any) = ifthenelse!(forest(f), f, g, h)
ifthenelse(f::Any, g::AbstractNode, h::Any) = ifthenelse!(forest(g), f, g, h)
ifthenelse(f::Any, g::Any, h::AbstractNode) = ifthenelse!(forest(h), f, g, h)
ifthenelse(f::Bool, g::Any, h::Any) = f ? g : h

ops = [:(<), :(<=), :(>), :(>=), :(==), :(!=), :(+), :(-), :(*), :(max), :(min)]
fns = [:lt!, :lte!, :gt!, :gte!, :eq!, :neq!, :plus!, :minus!, :mul!, :max!, :min!]
for (op, fn) = zip(ops, fns)
    @eval Base.$op(x::AbstractNode, y::AbstractNode) = $fn(forest(x), x, y)
    @eval Base.$op(x::AbstractNode, y::Any) = $fn(forest(x), x, value!(forest(x), y))
    @eval Base.$op(x::Any, y::AbstractNode) = $fn(forest(y), value!(forest(y), x), y)
end

Base.:(!)(x::AbstractNode) = not!(forest(x), x)
Base.:(-)(x::AbstractNode) = minus!(forest(x), value!(forest(x), 0), x)

"""
    genfunc!(b::Forest, xs::Vector{Vector{Value}})

Generate a function to MDD.
"""
function genfunc!(b::Forest, xs::Vector{Vector{Value}})
    vars = [var!(b, label(x)) for x = sort(collect(values(b.headers)), by=x->level(x))]
    mp = b.undet
    for x = xs
        tmp = value!(b, x[end])
        for (i,v) = enumerate(vars)
            nodes = AbstractNode[(x[i] == u) ? tmp : b.undet for u = domain(v)]
            tmp = node!(b, v.header, nodes)
        end
        mp = apply!(b, MDDUnion(), mp, tmp)
    end
    mp
end

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
            Expr(:call, :ifthenelse, _cond(x.args[2]), _cond(x.args[3]), _match(v[2:end]))
        else
            throw(ErrorException("Format error"))
        end
    else
        x = v[1]
        if Meta.isexpr(x, :call) && x.args[1] == :(=>) && x.args[2] == :(_)
            _cond(x.args[3])
        elseif Meta.isexpr(x, :call) && x.args[1] == :(=>)
            Expr(:call, :ifthenelse, _cond(x.args[2]), _cond(x.args[3]), :nothing)
        else
            throw(ErrorException("Format error"))
        end
    end
end

macro match(xs...)
    esc(_match(xs))
end

end
