"""
BDD Module
"""

module BDD

export bdd
export forest
export var!
export todot
export and, and!
export or, or!
export xor, xor!
export eq, eq!
export neq, neq!
export imp, imp!
export ifthenelse, ifthenelse!

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
const Level = Int

"""
    AbstractOperator
    AbstractUnaryOperator <: AbstractOperator
    AbstractBinaryOperator <: AbstractOperator
    NotOperator <: AbstractUnaryOperator
    AndOperator <: AbstractBinaryOperator
    OrOperator <: AbstractBinaryOperator
    XorOperator <: AbstractBinaryOperator
    EqOperator <: AbstractBinaryOperator
    NeqOperator <: AbstractBinaryOperator

Types for operations.
- NotOperator: Logical not operation
- AndOperator: Logical and operation
- OrOperator: Logical or operation
- XorOperator: Logical xor operation
- EqOperator: Logical eq operation
- NeqOperator: Logical neq operation
"""
abstract type AbstractOperator end
abstract type AbstractUnaryOperator <: AbstractOperator end
abstract type AbstractBinaryOperator <: AbstractOperator end
struct NotOperator <: AbstractUnaryOperator end
struct AndOperator <: AbstractBinaryOperator end
struct OrOperator <: AbstractBinaryOperator end
struct XorOperator <: AbstractBinaryOperator end
struct EqOperator <: AbstractBinaryOperator end
struct NeqOperator <: AbstractBinaryOperator end


"""
    AbstractPolicy
    FullyReduced <: AbstractPolicy
    QuasiReduced <: AbstractPolicy

The types for reduction policy in BDD.
- FullyReduced: the node is reduced if low and high nodes are same.
- QuasiReduced: the node is not reduced even if low and high nodes are same.
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
    Forest

A mutable structure to store the information on DD. The fields are
- mgr: NodeManager to issue IDs of nodes
- hmgr: NodeManager to issue IDs of headers
- utable: Unique table to identify the tuple (header id, low node id, high node id)
- zero: A terminal node indicating zero
- one: A terminal node indicating one
- cache: A cache for operations
"""
mutable struct Forest
    mgr::NodeManager
    hmgr::NodeManager
    utable::Dict{Tuple{NodeID,NodeID,NodeID},AbstractNode}
    zero::AbstractTerminalNode
    one::AbstractTerminalNode
    cache::Dict{Tuple{AbstractOperator,NodeID,NodeID},AbstractNode}
    policy::AbstractPolicy

    function Forest(policy::AbstractPolicy)
        b = new()
        b.mgr = NodeManager(0)
        b.hmgr = NodeManager(0)
        b.utable = Dict{Tuple{NodeID,NodeID,NodeID},AbstractNode}()
        b.zero = Terminal(b, _get_next!(b.mgr), false)
        b.one = Terminal(b, _get_next!(b.mgr), true)
        b.cache = Dict{Tuple{AbstractOperator,NodeID,NodeID},AbstractNode}()
        b.policy = policy
        b
    end
end

"""
    NodeHeader

A mutable structure indicating the information for nodes in the same level.
- id: Header ID
- level: Level of node. The level of terminal node is 0. 
- label: A symbol to represent the variable
"""
mutable struct NodeHeader
    id::NodeID
    level::Level
    label::Symbol

    function NodeHeader(id::NodeID, level::Level, label::Symbol)
        new(id, level, label)
    end
end

"""
    Node

A structure for a DD node.
- b: The forest that the node belogs to.
- id: Unique ID
- header: An instance of header class
- low: An instance of low node
- high: An instance of high node
"""
mutable struct Node <: AbstractNonTerminalNode
    b::Forest
    id::NodeID
    header::NodeHeader
    low::AbstractNode
    high::AbstractNode
end

"""
    node(b::Forest, h::NodeHeader, low::AbstractNode, high::AbstractNode)

Constructor of Node. If there exists any node which has same children in the same level,
the function returns the exisiting node. In addition, if the policy of forest is the FullyReduced,
the nodes with same directions are reduced.
- b: Forest
- h: NodeHeader
- low: Low node
- high: High node
"""
function node(b::Forest, h::NodeHeader, low::AbstractNode, high::AbstractNode)
    node(b, h, low, high, b.policy)
end

function node(b::Forest, h::NodeHeader, low::AbstractNode, high::AbstractNode, ::FullyReduced)
    if low.id == high.id
        return low
    end
    key = (h.id, low.id, high.id)
    get(b.utable, key) do
        id = _get_next!(b.mgr)
        b.utable[key] = Node(b, id, h, low, high)
    end
end

function node(b::Forest, h::NodeHeader, low::AbstractNode, high::AbstractNode, ::QuasiReduced)
    key = (h.id, low.id, high.id)
    get(b.utable, key) do
        id = _get_next!(b.mgr)
        b.utable[key] = Node(b, id, h, low, high)
    end
end


"""
    Terminal

A structure of Terminal node.
"""
mutable struct Terminal <: AbstractTerminalNode
    b::Forest
    id::NodeID
    value::Bool
end

"""
    Terminal

The constructor of terminal. The value is a boolean value.
"""
function Terminal(b::Forest, value::Bool)
    if value == true
        b.one
    else
        b.zero
    end
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
    return _apply!(b, op, f)
end

function apply!(b::Forest, op::AbstractBinaryOperator, f::AbstractNode, g::AbstractNode)
    return _apply!(b, op, f, g)
end

function _apply!(b::Forest, op::AbstractUnaryOperator, f::AbstractNonTerminalNode)
    key = (op, f.id, b.zero.id)
    get!(b.cache, key) do
        low = _apply!(b, op, f.low)
        high = _apply!(b, op, f.high)
        node(b, f.header, low, high)
    end
end

function _apply!(b::Forest, op::AbstractUnaryOperator, f::Bool)
    _apply!(b, op, Terminal(b, f))
end

function _apply!(b::Forest, op::AbstractBinaryOperator, f::AbstractNonTerminalNode, g::Bool)
    _apply!(b, op, f, Terminal(b, g))
end

function _apply!(b::Forest, op::AbstractBinaryOperator, f::Bool, g::AbstractNonTerminalNode)
    _apply!(b, op, Terminal(b, f), g)
end

function _apply!(b::Forest, op::AbstractBinaryOperator, f::Bool, g::Bool)
    _apply!(b, op, Terminal(b, f), Terminal(b, g))
end

function _apply!(b::Forest, op::AbstractBinaryOperator, f::AbstractNonTerminalNode, g::AbstractNonTerminalNode)
    key = (op, f.id, g.id)
    get(b.cache, key) do
        if f.header.level > g.header.level
            low = _apply!(b, op, f.low, g)
            high = _apply!(b, op, f.high, g)
            ans = node(b, f.header, low, high)
        elseif f.header.level < g.header.level
            low = _apply!(b, op, f, g.low)
            high = _apply!(b, op, f, g.high)
            ans = node(b, g.header, low, high)
        else
            low = _apply!(b, op, f.low, g.low)
            high = _apply!(b, op, f.high, g.high)
            ans = node(b, f.header, low, high)
        end
        b.cache[key] = ans
    end
end

function _apply!(b::Forest, op::AbstractBinaryOperator, f::AbstractTerminalNode, g::AbstractNonTerminalNode)
    key = (op, f.id, g.id)
    get(b.cache, key) do
        low = _apply!(b, op, f, g.low)
        high = _apply!(b, op, f, g.high)
        ans = node(b, g.header, low, high)
        b.cache[key] = ans
    end
end

function _apply!(b::Forest, op::AbstractBinaryOperator, f::AbstractNonTerminalNode, g::AbstractTerminalNode)
    key = (op, f.id, g.id)
    get(b.cache, key) do
        low = _apply!(b, op, f.low, g)
        high = _apply!(b, op, f.high, g)
        ans = node(b, f.header, low, high)
        b.cache[key] = ans
    end
end

## Concrete functions

### Not

function _apply!(b::Forest, ::NotOperator, f::Terminal)
    Terminal(b, !f.value)
end

### Eq

function _apply!(b::Forest, ::EqOperator, f::Terminal, g::Terminal)
    Terminal(b, f.value == g.value)
end

## Neq

function _apply!(b::Forest, ::NeqOperator, f::Terminal, g::Terminal)
    Terminal(b, f.value != g.value)
end

## And

function _apply!(b::Forest, ::AndOperator, f::Terminal, g::Node)
    if f.value == true
        g
    else
        b.zero
    end
end

function _apply!(b::Forest, ::AndOperator, f::Node, g::Terminal)
    if g.value == true
        f
    else
        b.zero
    end
end

function _apply!(b::Forest, ::AndOperator, f::Terminal, g::Terminal)
    Terminal(b, f.value && g.value)
end

## or

function _apply!(b::Forest, ::OrOperator, f::Terminal, g::Node)
    # assume f.value, g.value are bool
    if f.value == false
        g
    else
        b.one
    end
end

function _apply!(b::Forest, ::OrOperator, f::Node, g::Terminal)
    # assume f.value, g.value are bool
    if g.value == false
        f
    else
        b.one
    end
end

function _apply!(b::Forest, ::OrOperator, f::Terminal, g::Terminal)
    # assume f.value, g.value are bool
    Terminal(b, f.value || g.value)
end

## xor

function _apply!(b::Forest, ::XorOperator, f::Terminal, g::Terminal)
    # assume f.value, g.value are bool
    if f.value == g.value
        Terminal(b, false)
    else
        Terminal(b, true)
    end
end

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
    println(io, "\"obj$(f.id)\" [shape = square, label = \"$(ifelse(f.value, 1, 0))\"];")
    push!(visited, f.id)
    nothing
end

function _todot!(b::Forest, f::Node, visited::Set{NodeID}, io::IO)
    if in(f.id, visited)
        return
    end
    println(io, "\"obj$(f.id)\" [shape = circle, label = \"$(f.header.label)\"];")
    _todot!(b, f.low, visited, io)
    println(io, "\"obj$(f.id)\" -> \"obj$(f.low.id)\" [label = \"0\"];")
    _todot!(b, f.high, visited, io)
    println(io, "\"obj$(f.id)\" -> \"obj$(f.high.id)\" [label = \"1\"];")
    push!(visited, f.id)
    nothing
end

### utilities

"""
   bdd(policy::AbstractPolicy = FullyReduced())

Create BDD forest with the reduction policy.
"""
bdd(policy::AbstractPolicy = FullyReduced()) = Forest(policy)

"""
    var!(b::Forest, name::Symbol, level::Int)

Create a new variable.
- b: Forest
- name: Symbol of variable
- level: Level in BDD
"""
function var!(b::Forest, name::Symbol, level::Int)
    h = NodeHeader(_get_next!(b.hmgr), Level(level), name)
    node(b, h, Terminal(b, false), Terminal(b, true))
end

"""
    and(x::AbstractNode, xs...)
    and!(b::Forest, x::AbstractNode, xs...)

AND operation.
"""
function and!(b::Forest, x, xs...)
    tmp = x
    for u = xs
        tmp = apply!(b, AndOperator(), tmp, u)
    end
    tmp
end

function and(x::AbstractNode, xs...)
    and!(forest(x), x, xs...)
end

"""
    or(x::AbstractNode, xs...)
    or!(b::Forest, x::AbstractNode, xs...)

OR operation.
"""
function or!(b::Forest, x, xs...)
    tmp = x
    for u = xs
        tmp = apply!(b, OrOperator(), tmp, u)
    end
    tmp
end

function or(x::AbstractNode, xs...)
    or!(forest(x), x, xs...)
end

"""
    not(x::AbstractNode)
    not!(b::Forest, x::AbstractNode)

NOT operation.
"""
function not!(b::Forest, x)
    apply!(b, NotOperator(), x)
end

function not(x::AbstractNode)
    not!(forest(x), x)
end

"""
    xor(x::AbstractNode, xs...)
    xor!(b::Forest, x::AbstractNode, xs...)

XOR operation.
"""
function xor!(b::Forest, x, y)
    apply!(b, XorOperator(), x, y)
end

function Base.xor(x::AbstractNode, y)
    xor!(forest(x), x, y)
end

"""
   eq!(b::Forest, x, y)
   eq(x::AbstractNode, y)

EQ operation.
"""
function eq!(b::Forest, x, y)
    apply!(b, EqOperator(), x, y)
end

function eq(x::AbstractNode, y)
    eq!(forest(x), x, y)
end

"""
   neq!(b::Forest, x, y)
   neq(x::AbstractNode, y)

NEQ operation.
"""
function neq!(b::Forest, x, y)
    apply!(b, NeqOperator(), x, y)
end

function neq(x::AbstractNode, y)
    neq!(forest(x), x, y)
end

"""
   imp!(b::Forest, x, y)
   imp(x::AbstractNode, y)

IMP (imply) operation.
"""
function imp!(b::Forest, f, g)
    or!(b, not!(b, f), g)
end

function imp(f::AbstractNode, g)
    imp!(forest(f), f, g)
end

"""
   ifthenelse!(b::Forest, f, g, h)
   imp(x::AbstractNode, y)

IMP (imply) operation.
"""
function ifthenelse!(b::Forest, f, g, h)
    or!(b, and!(b, f, g), and!(b, not!(b, f), h))
end

function ifthenelse(f::AbstractNode, g, h)
    ifthenelse!(forest(f), f, g, h)
end

ops = [:(==), :(!=), :(&), :(|), :(⊻), :(*), :(+)]
fns = [:eq!, :xor!, :and!, :or!, :xor!, :and!, :or!]

for (op, fn) = zip(ops, fns)
    @eval Base.$op(x::AbstractNode, y) = $fn(forest(x), x, y)
end

Base.:(!)(x::AbstractNode) = not!(forest(x), x)
Base.:(~)(x::AbstractNode) = not!(forest(x), x)

end
