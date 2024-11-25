module SDD

const NodeID = UInt
const Level = UInt

mutable struct NodeManager
    nextid::NodeID
end

function _get_next!(mgr::NodeManager)::NodeID
    id = mgr.nextid
    mgr.nextid += 1
    id
end

abstract type AbstractVtreeNode end
abstract type AbstractVtreeNonVarNode <: AbstractVtreeNode end
abstract type AbstractVtreeVarNode <: AbstractVtreeNode end

abstract type AbstractVtreeToken end

mutable struct VtreeNode <: AbstractVtreeNonVarNode
    id::NodeID
    left::AbstractVtreeNode
    right::AbstractVtreeNode
end

mutable struct VtreeVarNode <: AbstractVtreeVarNode
    id::NodeID
    var::Symbol
end

# struct VtreeTokenSymbol <: AbstractVtreeToken
#     var::Symbol
# end

# struct VtreeTokenSep <: AbstractVtreeToken end

# # make vtree from a sequence of tokens based on RPN
# function make_vtree(tokens::Vector{AbstractVtreeToken})
#     id = UInt(1)
#     stack = Vector{AbstractVtreeNode}()
#     for token in tokens
#         if isa(token, VtreeTokenSymbol)
#             push!(stack, VtreeVarNode(id, token.var))
#             id += 1
#         elseif isa(token, VtreeTokenSep)
#             right = pop!(stack)
#             left = pop!(stack)
#             push!(stack, VtreeNode(id, left, right))
#             id += 1
#         end
#     end
#     if length(stack) != 1
#         throw(ArgumentError("Invalid Vtree"))
#     end
#     stack[1]
# end

# function the expression (x < y) < z to make the vtree directly
function make_vtree(x::Expr, mgr::NodeManager)
    if x.head == :call
        if x.args[1] == :<
            left = make_vtree(x.args[2], mgr)
            id = _get_next!(mgr)
            right = make_vtree(x.args[3], mgr)
            return VtreeNode(id, left, right)
        elseif x.args[1] == :>
            right = make_vtree(x.args[2], mgr)
            id = _get_next!(mgr)
            left = make_vtree(x.args[3], mgr)
            return VtreeNode(id, left, right)
        else
            throw(ArgumentError("Invalid expression"))
        end
    elseif x.head == :comparison
        if length(x.args) == 3
            leftexpr, op, rightexpr = x.args
            if op == :<
                left = make_vtree(leftexpr, mgr)
                id = _get_next!(mgr)
                right = make_vtree(rightexpr, mgr)
                return VtreeNode(id, left, right)
            elseif op == :>
                right = make_vtree(leftexpr, mgr)
                id = _get_next!(mgr)
                left = make_vtree(rightexpr, mgr)
                return VtreeNode(id, left, right)
            else
                throw(ArgumentError("Invalid expression"))
            end
        elseif length(x.args) > 3
            leftexpr, op, rightexpr = x.args[1], x.args[2], Expr(:comparison, x.args[3:end]...)
            if op == :<
                left = make_vtree(leftexpr, mgr)
                id = _get_next!(mgr)
                right = make_vtree(rightexpr, mgr)
                return VtreeNode(id, left, right)
            elseif op == :>
                right = make_vtree(leftexpr, mgr)
                id = _get_next!(mgr)
                left = make_vtree(rightexpr, mgr)
                return VtreeNode(id, left, right)
            else
                throw(ArgumentError("Invalid expression"))
            end
        else
            throw(ArgumentError("Invalid expression"))
        end
    else
        throw(ArgumentError("Invalid expression"))
    end
end

function make_vtree(x::Symbol, mgr::NodeManager)
    VtreeVarNode(_get_next!(mgr), x)
end

# macro to call make_vtree
macro vtree(x)
    mgr = NodeManager(1)
    make_vtree(x, mgr)
end

# todot for vtree to convert vtree to DOT format
function todot(v::AbstractVtreeNode)
    s = "digraph G {\n"
    s *= "graph [ranksep=1.0, nodesep=0.5];\n"
    s *= "node [shape=plaintext];\n"
    s *= _todot(v)
    s *= "}\n"
    s
end

function _todot(v::AbstractVtreeNonVarNode)
    s = "n$(v.id) [label=\"$(v.id)\", shape=plain];\n"
    if v.left isa AbstractVtreeVarNode
        s *= "n$(v.id) -> n$(v.left.id) [headlabel=\"$(v.left.id)\", arrowhead=none];\n"
    else
        s *= "n$(v.id) -> n$(v.left.id) [arrowhead=none];\n"
    end
    if v.right isa AbstractVtreeVarNode
        s *= "n$(v.id) -> n$(v.right.id) [headlabel=\"$(v.right.id)\", arrowhead=none];\n"
    else
        s *= "n$(v.id) -> n$(v.right.id) [arrowhead=none];\n"
    end
    s *= _todot(v.left)
    s *= _todot(v.right)
    return s
end

function _todot(v::AbstractVtreeVarNode)
    "n$(v.id) [label=\"$(v.var)\", shape=plain];\n"
end

abstract type AbstractOperator end

struct AndOperator <: AbstractOperator
    id::Symbol

    function AndOperator()
        new(:and)
    end
end

struct OrOperator <: AbstractOperator
    id::Symbol

    function OrOperator()
        new(:or)
    end
end

struct NotOperator <: AbstractOperator
    id::Symbol
    
    function NotOperator()
        new(:not)
    end
end

abstract type AbstractNode end
abstract type AbstractNonTerminalNode <: AbstractNode end
abstract type AbstractTerminalNode <: AbstractNode end
abstract type AbstractVarTerminalNode <: AbstractTerminalNode end
abstract type AbstractConstantTerminalNode <: AbstractTerminalNode end

mutable struct Element
    id::NodeID
    prime::AbstractNode
    sub::AbstractNode
end

mutable struct SDDHeader
    id::NodeID
    node::AbstractVtreeNode
    vars::Set{Symbol}
end

mutable struct Forest
    mgr::NodeManager
    vars::Dict{Symbol,NamedTuple{(:T,:F),Tuple{AbstractNode,AbstractNode}}}
    headers::Dict{NodeID,SDDHeader}
    vtree::AbstractVtreeNode
    utable::Dict{Tuple{NodeID,Vector{NodeID}},AbstractNode}
    elementtable::Dict{Tuple{NodeID,NodeID},Element}
    vtable::Dict{Tuple{NodeID,Bool},AbstractNode}
    T::AbstractConstantTerminalNode
    F::AbstractConstantTerminalNode
    cache::Dict{Tuple{NodeID,NodeID,Symbol},AbstractNode}

    function Forest(vtree::AbstractVtreeNode)
        b = new()
        b.vtree = vtree
        b.mgr = NodeManager(1)
        b.utable = Dict{Tuple{NodeID,Vector{NodeID}},AbstractNode}()
        b.elementtable = Dict{Tuple{NodeID,NodeID},Element}()
        b.vtable = Dict{Tuple{NodeID,Bool},AbstractNode}()
        b.T = SDDTerminalConstantNode(b, _get_next!(b.mgr), true)
        b.F = SDDTerminalConstantNode(b, _get_next!(b.mgr), false)
        b.cache = Dict{Tuple{NodeID,NodeID,Symbol},AbstractNode}()
        b.vars = Dict{Symbol,NamedTuple{(:T,:F),Tuple{AbstractNode,AbstractNode}}}()
        b.headers = Dict{NodeID,SDDHeader}()
        _make_headers!(b, vtree)
        b
    end
end

# override for display
function Base.show(io::IO, x::AbstractVarTerminalNode)
    print(io, get_var_symbol(x))
end

function Base.show(io::IO, x::AbstractConstantTerminalNode)
    if x.value
        print(io, "true")
    else
        print(io, "false")
    end
end

function Base.show(io::IO, x::AbstractNonTerminalNode)
    print(io, "n$(x.id) $(x.header.id) $(x.vars)")
end

function Base.show(io::IO, x::Forest)
    print(io, "Forest($(x.vtree), $(length(x.utable)), $(length(x.elementtable)), $(length(x.vtable))")
end

# function to make headers by traversing the vtree
function _make_headers!(b::Forest, v::AbstractVtreeNode)
    if v isa VtreeVarNode
        tmp = Set([v.var])
        h = SDDHeader(v.id, v, tmp)
        b.headers[v.id] = h
        b.vars[v.var] = (T=_var!(b, h, true), F=_var!(b, h, false))
        return tmp
    end
    left = _make_headers!(b, v.left)
    right = _make_headers!(b, v.right)
    tmp = union(left, right)
    b.headers[v.id] = SDDHeader(v.id, v, tmp)
    return tmp
end

# find the header whose vars includes both h1.vars[1] and h2.vars[1] form h1.id to h2.id
function findheader(b::Forest, h1::SDDHeader, h2::SDDHeader)
    if h1.id > h2.id
        h1, h2 = h2, h1
    end
    for i = h1.id:h2.id
        h = b.headers[i]
        if issubset(union(h1.vars, h2.vars), h.vars)
            return h
        end
    end
end

function isleft(h1::SDDHeader, h2::SDDHeader)
    return h2.id < h1.id && issubset(h2.vars, h1.vars)
end

function isright(h1::SDDHeader, h2::SDDHeader)
    return h2.id > h1.id && issubset(h2.vars, h1.vars)
end

function get_var_symbol(x::AbstractVarTerminalNode)
    first(x.header.vars)
end

mutable struct SDDNonTerminalNode <: AbstractNonTerminalNode
    b::Forest
    id::NodeID
    header::SDDHeader
    elements::Vector{Element}
end

mutable struct SDDTerminalVarNode <: AbstractVarTerminalNode
    b::Forest
    id::NodeID
    header::SDDHeader
    value::Bool
end

mutable struct SDDTerminalConstantNode <: AbstractConstantTerminalNode
    b::Forest
    id::NodeID
    value::Bool
end

function _node!(b::Forest, h::SDDHeader, _elements::Vector{Element})
    sort!(_elements, by=x->x.sub.id)
    elements = Vector{Element}()
    prev = _elements[1]
    for e = _elements[2:end]
        if prev.sub.id != e.sub.id
            push!(elements, prev)
            prev = e
        else
            prev = _element!(b, _apply!(b, OrOperator(), prev.prime, e.prime, cache=b.cache), e.sub)
        end
    end
    push!(elements, prev)
    # elements = _elements
    sort!(elements, by=x->x.prime.id)
    if length(elements) == 1 && elements[1].prime == b.T
        return elements[1].sub
    elseif length(elements) == 2 && elements[1].sub == b.T && elements[2].sub == b.F
        return elements[1].prime
    elseif length(elements) == 2 && elements[1].sub == b.F && elements[2].sub == b.T
        return elements[2].prime
    end
    key = (h.id, [x.id for x = elements])
    get(b.utable, key) do
        id = _get_next!(b.mgr)
        b.utable[key] = SDDNonTerminalNode(b, id, h, elements)
    end
end

function _element!(b::Forest, prime::AbstractNode, sub::AbstractNode)
    key = (prime.id, sub.id)
    get(b.elementtable, key) do
        id = _get_next!(b.mgr)
        b.elementtable[key] = Element(id, prime, sub)
    end
end

function _var!(b::Forest, h::SDDHeader, value::Bool)
    key = (h.id, value)
    get(b.vtable, key) do
        id = _get_next!(b.mgr)
        b.vtable[key] = SDDTerminalVarNode(b, id, h, value)
    end
end

# output DOT format to draw the SDD
function _todot(x::AbstractNonTerminalNode, visited_elements::Set{Element}, visited_nodes::Set{AbstractNode})
    if x in visited_nodes
        return ""
    end
    s = "n$(x.id) [label=\"$(x.header.id)\", shape=circle];\n"
    for e in x.elements
        s *= _todot(e, visited_elements, visited_nodes)
        s *= "n$(x.id) -> e$(e.id);\n"
    end
    push!(visited_nodes, x)
    s
end

function _todot(x::Element, visited_elements::Set{Element}, visited_nodes::Set{AbstractNode})
    if x in visited_elements
        return ""
    end
    label = "<<TABLE BORDER=\"0\" CELLBORDER=\"1\" CELLSPACING=\"0\"><TR><TD PORT=\"L\">"
    if x.prime isa AbstractVarTerminalNode
        if x.prime.value
            label *= "&#160;$(get_var_symbol(x.prime))&#160;"
        else
            label *= "&#160;$(get_var_symbol(x.prime))&#773;"
        end
    elseif x.prime isa AbstractConstantTerminalNode
        if x.prime.value
            label *= "&#160;&#8868;&#160;"
        else
            label *= "&#160;&#8869;&#160;"
        end
    else
        label *= "&#160;&#160;&#160;"
    end
    label *= "</TD><TD PORT=\"R\">"
    if x.sub isa AbstractVarTerminalNode
        if x.sub.value
            label *= "&#160;$(get_var_symbol(x.sub))&#160;"
        else
            label *= "&#160;$(get_var_symbol(x.sub))&#773;"
        end
    elseif x.sub isa AbstractConstantTerminalNode
        if x.sub.value
            label *= "&#160;&#8868;&#160;"
        else
            label *= "&#160;&#8869;&#160;"
        end
    else
        label *= "&#160;&#160;&#160;"
    end
    label *= "</TD></TR></TABLE>>"
    s = "e$(x.id) [label=$(label), shape=plain];\n"
    if x.prime isa AbstractNonTerminalNode
        s *= "e$(x.id):L:c -> n$(x.prime.id) [tailclip=false,arrowtail=dot,dir=both];\n"
        s *= _todot(x.prime, visited_elements, visited_nodes)
    end
    if x.sub isa AbstractNonTerminalNode
        s *= "e$(x.id):R:c -> n$(x.sub.id) [tailclip=false,arrowtail=dot,dir=both];\n"
        s *= _todot(x.sub, visited_elements, visited_nodes)
    end
    push!(visited_elements, x)
    s
end

function _todot(x::AbstractVarTerminalNode, visited_elements, visited_nodes)
    if x in visited_nodes
        return ""
    end
    push!(visited_nodes, x)
    ""
end

function _todot(x::AbstractConstantTerminalNode, visited_elements, visited_nodes)
    if x in visited_nodes
        return ""
    end
    push!(visited_nodes, x)
    ""
end

function todot(x::AbstractNode)
    visited_elements = Set{Element}()
    visited_nodes = Set{AbstractNode}()
    s = "digraph G {\n"
    s *= "graph [ranksep=1.0, nodesep=0.5];\n"
    s *= "node [shape=plaintext];\n"
    s *= _todot(x, visited_elements, visited_nodes)
    s *= "}\n"
    s
end

function not!(b::Forest, n::AbstractVarTerminalNode; cache::Dict{Tuple{NodeID,NodeID,Symbol},AbstractNode})
    get!(cache, (n.id, 0, :not)) do
        if n.value
            b.vars[first(n.header.vars)].F
        else
            b.vars[first(n.header.vars)].T
        end
    end
end

function not!(b::Forest, n::AbstractConstantTerminalNode; cache::Dict{Tuple{NodeID,NodeID,Symbol},AbstractNode})
    get!(cache, (n.id, 0, :not)) do
        if n.value
            b.F
        else
            b.T
        end
    end
end

function not!(b::Forest, n::AbstractNonTerminalNode; cache::Dict{Tuple{NodeID,NodeID,Symbol},AbstractNode})
    get!(cache, (n.id, 0, :not)) do
        elements = Vector{Element}()
        for e in n.elements
            push!(elements, _element!(b, e.prime, not!(b, e.sub, cache=cache)))
        end
        _node!(b, n.header, elements)
    end
end

## binary

function _apply!(b::Forest, op::AbstractOperator, f::AbstractNonTerminalNode, g::AbstractNonTerminalNode; cache::Dict{Tuple{NodeID,NodeID,Symbol},AbstractNode})
    get!(cache, (f.id, g.id, op.id)) do
        if f.header.id == g.header.id
            elements = Vector{Element}()
            for felem = f.elements
                for gelem = g.elements
                    p = _apply!(b, AndOperator(), felem.prime, gelem.prime, cache=cache)
                    if p != b.F
                        s = _apply!(b, op, felem.sub, gelem.sub)
                        push!(elements, _element!(b, p, s))
                    end
                end
            end
            _node!(b, f.header, elements)
        elseif isleft(f.header, g.header) ## g.header is left (prime) of f.header 
            elements = Vector{Element}()
            for felem = f.elements
                p = _apply!(b, AndOperator(), felem.prime, g, cache=cache)
                if p != b.F
                    s = _apply!(b, op, felem.sub, b.T, cache=cache)
                    push!(elements, _element!(b, p, s))
                end
            end
            for felem = f.elements
                p = _apply!(b, AndOperator(), felem.prime, not!(b, g, cache=cache), cache=cache)
                if p != b.F
                    s = _apply!(b, op, felem.sub, b.F, cache=cache)
                    push!(elements, _element!(b, p, s))
                end
            end
            _node!(b, f.header, elements)
        elseif isright(f.header, g.header) ## g.header is right (sub) of f.header
            elements = Vector{Element}()
            for felem = f.elements
                p = felem.prime
                s = _apply!(b, op, felem.sub, g, cache=cache)
                push!(elements, _element!(b, p, s))
            end
            _node!(b, f.header, elements)
        elseif isleft(g.header, f.header) ## f.header is left (prime) of g.header
            elements = Vector{Element}()
            for gelem = g.elements
                p = _apply!(b, AndOperator(), f, gelem.prime, cache=cache)
                if p != b.F
                    s = _apply!(b, op, b.T, gelem.sub, cache=cache)
                    push!(elements, _element!(b, p, s))
                end
            end
            for gelem = g.elements
                p = _apply!(b, AndOperator(), not!(b, f, cache=cache), gelem.prime, cache=cache)
                if p != b.F
                    s = _apply!(b, op, b.F, gelem.sub, cache=cache)
                    push!(elements, _element!(b, p, s))
                end
            end
            _node!(b, g.header, elements)
        elseif isright(g.header, f.header) ## f.header is right (sub) of g.header
            elements = Vector{Element}()
            for gelem = g.elements
                p = gelem.prime
                s = _apply!(b, op, f, gelem.sub, cache=cache)
                push!(elements, _element!(b, p, s))
            end
            _node!(b, g.header, elements)
        else
            h = findheader(b, f.header, g.header)
            if isleft(h, f.header) && isright(h, g.header)
                elements = Vector{Element}()
                p = f
                s = _apply!(b, op, b.T, g, cache=cache)
                push!(elements, _element!(b, p, s))
                p = not!(b, f, cache=cache)
                s = _apply!(b, op, b.F, g, cache=cache)
                push!(elements, _element!(b, p, s))
                _node!(b, h, elements)
            elseif isright(h, f.header) && isleft(h, g.header)
                elements = Vector{Element}()
                p = g
                s = _apply!(b, op, f, b.T, cache=cache)
                push!(elements, _element!(b, p, s))
                p = not!(b, g, cache=cache)
                s = _apply!(b, op, f, b.F, cache=cache)
                push!(elements, _element!(b, p, s))
                _node!(b, h, elements)
            else
                @assert false "Invalid SDD"
            end
        end
    end
end

function _apply!(b::Forest, op::AbstractOperator, f::AbstractVarTerminalNode, g::AbstractNonTerminalNode; cache::Dict{Tuple{NodeID,NodeID,Symbol},AbstractNode})
    get!(cache, (f.id, g.id, op.id)) do
        if isleft(g.header, f.header) # f.header is left (prime) of g.header
            elements = Vector{Element}()
            for geleme = g.elements
                p = _apply!(b, AndOperator(), f, geleme.prime, cache=cache)
                if p != b.F
                    s = _apply!(b, op, b.T, geleme.sub, cache=cache)
                    push!(elements, _element!(b, p, s))
                end
            end
            for geleme = g.elements
                p = _apply!(b, AndOperator(), not!(b, f, cache=cache), geleme.prime, cache=cache)
                if p != b.F
                    s = _apply!(b, op, b.F, geleme.sub, cache=cache)
                    push!(elements, _element!(b, p, s))
                end
            end
            _node!(b, g.header, elements)
        elseif isright(g.header, f.header) # f.header is right (sub) of g.header
            elements = Vector{Element}()
            for geleme = g.elements
                p = geleme.prime
                s = _apply!(b, op, f, geleme.sub, cache=cache)
                push!(elements, _element!(b, p, s))
            end
            _node!(b, g.header, elements)
        else
            h = findheader(b, f.header, g.header)
            if isleft(h, f.header) && isright(h, g.header)
                elements = Vector{Element}()
                p = f
                s = _apply!(b, op, b.T, g, cache=cache)
                push!(elements, _element!(b, p, s))
                p = not!(b, f, cache=cache)
                s = _apply!(b, op, b.F, g, cache=cache)
                push!(elements, _element!(b, p, s))
                _node!(b, h, elements)
            elseif isright(h, f.header) && isleft(h, g.header)
                elements = Vector{Element}()
                p = g
                s = _apply!(b, op, f, b.T, cache=cache)
                push!(elements, _element!(b, p, s))
                p = not!(b, g, cache=cache)
                s = _apply!(b, op, f, b.F, cache=cache)
                push!(elements, _element!(b, p, s))
                _node!(b, h, elements)
            else
                @assert false "Invalid SDD"
            end
        end
    end
end

function _apply!(b::Forest, op::AbstractOperator, f::AbstractNonTerminalNode, g::AbstractVarTerminalNode; cache::Dict{Tuple{NodeID,NodeID,Symbol},AbstractNode})
    get!(cache, (f.id, g.id, op.id)) do
        if isleft(f.header, g.header) # g.header is left (prime) of f.header
            elements = Vector{Element}()
            for feleme = f.elements
                p = _apply!(b, AndOperator(), feleme.prime, g, cache=cache)
                if p != b.F
                    s = _apply!(b, op, feleme.sub, b.T, cache=cache)
                    push!(elements, _element!(b, p, s))
                end
            end
            for feleme = f.elements
                p = _apply!(b, AndOperator(), feleme.prime, not!(b, g, cache=cache), cache=cache)
                if p != b.F
                    s = _apply!(b, op, feleme.sub, b.F, cache=cache)
                    push!(elements, _element!(b, p, s))
                end
            end
            _node!(b, f.header, elements)
        elseif isright(f.header, g.header) # g.header is right (sub) of f.header
            elements = Vector{Element}()
            for feleme = f.elements
                p = feleme.prime
                s = _apply!(b, op, feleme.sub, g, cache=cache)
                push!(elements, _element!(b, p, s))
            end
            _node!(b, f.header, elements)
        else
            h = findheader(b, f.header, g.header)
            if isleft(h, f.header) && isright(h, g.header)
                elements = Vector{Element}()
                p = f
                s = _apply!(b, op, b.T, g, cache=cache)
                push!(elements, _element!(b, p, s))
                p = not!(b, f, cache=cache)
                s = _apply!(b, op, b.F, g, cache=cache)
                push!(elements, _element!(b, p, s))
                _node!(b, h, elements)
            elseif isright(h, f.header) && isleft(h, g.header)
                elements = Vector{Element}()
                p = g
                s = _apply!(b, op, f, b.T, cache=cache)
                push!(elements, _element!(b, p, s))
                p = not!(b, g, cache=cache)
                s = _apply!(b, op, f, b.F, cache=cache)
                push!(elements, _element!(b, p, s))
                _node!(b, h, elements)
            else
                @assert false "Invalid SDD"
            end
        end
    end
end

function _apply!(b::Forest, op::AbstractOperator, f::AbstractConstantTerminalNode, g::AbstractNonTerminalNode; cache::Dict{Tuple{NodeID,NodeID,Symbol},AbstractNode})
    get!(cache, (f.id, g.id, op.id)) do
        elements = Vector{Element}()
        for gelem = g.elements
            p = gelem.prime
            s = _apply!(b, op, f, gelem.sub, cache=cache)
            push!(elements, _element!(b, p, s))
        end
        _node!(b, g.header, elements)
    end
end

function _apply!(b::Forest, op::AbstractOperator, f::AbstractNonTerminalNode, g::AbstractConstantTerminalNode; cache::Dict{Tuple{NodeID,NodeID,Symbol},AbstractNode})
    get!(cache, (f.id, g.id, op.id)) do
        elements = Vector{Element}()
        for felem = f.elements
            p = felem.prime
            s = _apply!(b, op, felem.sub, g, cache=cache)
            push!(elements, _element!(b, p, s))
        end
        _node!(b, f.header, elements)
    end
end

### and

function _apply!(b::Forest, ::AndOperator, f::AbstractVarTerminalNode, g::AbstractVarTerminalNode; cache::Dict{Tuple{NodeID,NodeID,Symbol},AbstractNode})
    get!(cache, (f.id, g.id, :and)) do
        if f.header.id == g.header.id && f.value == g.value
            return f
        elseif f.header.id == g.header.id && f.value != g.value
            return b.F
        else
            h = findheader(b, f.header, g.header)
            if isleft(h, f.header) && isright(h, g.header)
                elements = Vector{Element}()
                push!(elements, _element!(b, f, g))
                push!(elements, _element!(b, not!(b, f, cache=cache), b.F))
                _node!(b, h, elements)
            elseif isright(h, f.header) && isleft(h, g.header)
                elements = Vector{Element}()
                push!(elements, _element!(b, g, f))
                push!(elements, _element!(b, not!(b, g, cache=cache), b.F))
                _node!(b, h, elements)
            else
                throw(ArgumentError("Invalid SDD"))
            end
        end
    end
end

function _apply!(b::Forest, ::AndOperator, f::AbstractConstantTerminalNode, g::AbstractVarTerminalNode; cache::Dict{Tuple{NodeID,NodeID,Symbol},AbstractNode})
    if f.value
        return g
    else
        return b.F
    end
end

function _apply!(b::Forest, ::AndOperator, f::AbstractVarTerminalNode, g::AbstractConstantTerminalNode; cache::Dict{Tuple{NodeID,NodeID,Symbol},AbstractNode})
    if g.value
        return f
    else
        return b.F
    end
end

function _apply!(b::Forest, ::AndOperator, f::AbstractConstantTerminalNode, g::AbstractConstantTerminalNode; cache::Dict{Tuple{NodeID,NodeID,Symbol},AbstractNode})
    if f.value && g.value
        return b.T
    else
        return b.F
    end
end

### or

function _apply!(b::Forest, ::OrOperator, f::AbstractVarTerminalNode, g::AbstractVarTerminalNode; cache::Dict{Tuple{NodeID,NodeID,Symbol},AbstractNode})
    get!(cache, (f.id, g.id, :or)) do
        if f.header.id == g.header.id && f.value == g.value
            return f
        elseif f.header.id == g.header.id && f.value != g.value
            return b.T
        else
            h = findheader(b, f.header, g.header)
            if isleft(h, f.header) && isright(h, g.header)
                elements = Vector{Element}()
                push!(elements, _element!(b, f, b.T))
                push!(elements, _element!(b, not!(b, f, cache=cache), g))
                _node!(b, h, elements)
            elseif isright(h, f.header) && isleft(h, g.header)
                elements = Vector{Element}()
                push!(elements, _element!(b, g, b.T))
                push!(elements, _element!(b, not!(b, g, cache=cache), f))
                _node!(b, h, elements)
            else
                throw(ArgumentError("Invalid SDD"))
            end
        end
    end
end

function _apply!(b::Forest, ::OrOperator, f::AbstractConstantTerminalNode, g::AbstractVarTerminalNode; cache::Dict{Tuple{NodeID,NodeID,Symbol},AbstractNode})
    if f.value
        return b.T
    else
        return g
    end
end

function _apply!(b::Forest, ::OrOperator, f::AbstractVarTerminalNode, g::AbstractConstantTerminalNode; cache::Dict{Tuple{NodeID,NodeID,Symbol},AbstractNode})
    if g.value
        return b.T
    else
        return f
    end
end

function _apply!(b::Forest, ::OrOperator, f::AbstractConstantTerminalNode, g::AbstractConstantTerminalNode; cache::Dict{Tuple{NodeID,NodeID,Symbol},AbstractNode})
    if f.value || g.value
        return b.T
    else
        return b.F
    end
end

###

function and(f::AbstractNode, g::AbstractNode)
    _apply!(f.b, AndOperator(), f, g, cache=f.b.cache)
end

function or(f::AbstractNode, g::AbstractNode)
    _apply!(f.b, OrOperator(), f, g, cache=f.b.cache)
end

function not(f::AbstractNode)
    not!(f.b, f, cache=f.b.cache)
end

## override for operations

function Base.:&(f::AbstractNode, g::AbstractNode)
    and(f, g)
end

function Base.:|(f::AbstractNode, g::AbstractNode)
    or(f, g)
end

function Base.:~(f::AbstractNode)
    not(f)
end

function Base.:&(f::AbstractNode, g::Bool)
    if g
        f
    else
        f.b.F
    end
end

function Base.:|(f::AbstractNode, g::Bool)
    if g
        f.b.T
    else
        f
    end
end

function Base.:&(f::Bool, g::AbstractNode)
    if f
        g
    else
        g.b.F
    end
end

function Base.:|(f::Bool, g::AbstractNode)
    if f
        g.b.T
    else
        g
    end
end

end # module SDD