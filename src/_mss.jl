"""
MSS
"""

#export bdd, header!, var!, node!, not, and, or, xor, imp, ite, todot

mutable struct MSSVariable{Ts,Tx}
    label::Ts
    domain::Vector{Tx}
    header::NodeHeader
    f::AbstractNode
end

mutable struct MSS{Ts,Tx}
    vars::Dict{Ts,MSSVariable{Ts,Tx}}
    dd::MDDForest

    function MSS(::Type{Ts} = Symbol, ::Type{Tx} = ValueT) where {Ts,Tx}
        dd = MDDForest()
        vv = Dict{Ts,MSSVariable{Ts,Tx}}()
        new{Ts,Tx}(vv, dd)
    end
end

function var!(mss::MSS{Ts,Tx}, name::Ts, domain::Vector{Tx}) where {Ts,Tx}
    header = NodeHeader(length(mss.vars), length(domain))
    f = Node(mss.dd, header, AbstractNode[Terminal(mss.dd, x) for x = domain])
    mss.vars[name] = MSSVariable{Ts,Tx}(name, domain, header, f)
    f
end

function val!(mss::MSS{Ts,Tx}, value::Tx) where {Ts,Tx}
    val!(mss.dd, value)
end

## macro

function _cond(mss, s::Any)
    s
end

function _cond(mss, s::Symbol)
    s
end

function _cond(mss, s::Integer)
    Expr(:call, :val!, mss, s)
end

function _cond(mss, x::Expr)
    if Meta.isexpr(x, :call)
        if x.args[1] == :(==)
            Expr(:call, :eq!, mss, _cond(mss, x.args[2]), _cond(mss, x.args[3]))
        elseif x.args[1] == :(!=)
            Expr(:call, :neq!, mss, _cond(mss, x.args[2]), _cond(mss, x.args[3]))
        elseif x.args[1] == :(>=)
            Expr(:call, :gte!, mss, _cond(mss, x.args[2]), _cond(mss, x.args[3]))
        elseif x.args[1] == :(<=)
            Expr(:call, :lte!, mss, _cond(mss, x.args[2]), _cond(mss, x.args[3]))
        elseif x.args[1] == :(>)
            Expr(:call, :gt!, mss, _cond(mss, x.args[2]), _cond(mss, x.args[3]))
        elseif x.args[1] == :(<)
            Expr(:call, :lt!, mss, _cond(mss, x.args[2]), _cond(mss, x.args[3]))
        elseif x.args[1] == :max
            Expr(:call, :max!, mss, [_cond(mss, u) for u = x.args[2:end]]...)
        elseif x.args[1] == :min
            Expr(:call, :min!, mss, [_cond(mss, u) for u = x.args[2:end]]...)
        else
            throw(ErrorException("Function expression: Available functions are ==, !=, >=, <=, >, <, max, min"))
        end
    elseif Meta.isexpr(x, :(&&))
        Expr(:call, :and!, mss, _cond(mss, x.args[1]), _cond(mss, x.args[2]))
    elseif Meta.isexpr(x, :(||))
        Expr(:call, :or!, mss, _cond(mss, x.args[1]), _cond(mss, x.args[2]))
    else
        throw(ErrorException("Expression error"))
    end
end

function _branch(mss, v::Vector{Expr})
    if length(v) > 1
        x = v[1]
        if Meta.isexpr(x, :call)
            if x.args[1] == :(=>)
                Expr(:call, :ifelse!, mss, _cond(mss, x.args[2]), _cond(mss, x.args[3]), _branch(mss, v[2:end]))
            end
        end
    else
        x = v[1]
        if Meta.isexpr(x, :call) && x.args[1] == :(=>) && x.args[2] == :(_)
            _cond(mss, x.args[3])
        else
            throw(ErrorException("The end of condition should be '_ => x'"))
        end
    end
end

function _mss(mss, b::Expr)
    if Meta.isexpr(b, :block)
        match = [v for v = b.args if Meta.isexpr(v, :call) && v.args[1] == :(=>)]
    end
    _branch(mss, match)
end

macro mss(s, b)
    esc(_mss(s, b))
end
