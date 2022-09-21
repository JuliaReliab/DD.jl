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

function _cond(mss, x::Expr)
    if Meta.isexpr(x, :call)
        if x.args[1] == :(==) && typeof(x.args[3]) <: Integer
            Expr(:call, :eq!, mss, _cond(mss, x.args[2]), Expr(:call, :val!, mss, x.args[3]))
        elseif x.args[1] == :(!=) && typeof(x.args[3]) <: Integer
            Expr(:call, :neq!, mss, _cond(mss, x.args[2]), Expr(:call, :val!, mss, x.args[3]))
        elseif x.args[1] == :(>=) && typeof(x.args[3]) <: Integer
            Expr(:call, :gte!, mss, _cond(mss, x.args[2]), Expr(:call, :val!, mss, x.args[3]))
        elseif x.args[1] == :(<=) && typeof(x.args[3]) <: Integer
            Expr(:call, :lte!, mss, _cond(mss, x.args[2]), Expr(:call, :val!, mss, x.args[3]))
        elseif x.args[1] == :(>) && typeof(x.args[3]) <: Integer
            Expr(:call, :gt!, mss, _cond(mss, x.args[2]), Expr(:call, :val!, mss, x.args[3]))
        elseif x.args[1] == :(<) && typeof(x.args[3]) <: Integer
            Expr(:call, :lt!, mss, _cond(mss, x.args[2]), Expr(:call, :val!, mss, x.args[3]))
        else
            throw(ErrorException("Condition error: The expression should be like x >= 0"))
        end
    elseif Meta.isexpr(x, :(&&))
        Expr(:call, :and!, mss, _cond(mss, x.args[1]), _cond(mss, x.args[2]))
    elseif Meta.isexpr(x, :(||))
        Expr(:call, :or!, mss, _cond(mss, x.args[1]), _cond(mss, x.args[2]))
    else
        throw(ErrorException("Condition expression error"))
    end
end

function _branch(mss, v::Vector{Expr})
    if length(v) > 1
        x = v[1]
        println(x)
        if Meta.isexpr(x, :call)
            if x.args[1] == :(=>) && typeof(x.args[3]) <: Integer
                Expr(:call, :ifelse!, mss, _cond(mss, x.args[2]),
                Expr(:call, :val!, mss, x.args[3]),
                    _branch(mss, v[2:end]))
            end
        end
    else
        x = v[1]
        if Meta.isexpr(x, :call) && x.args[1] == :(=>) && x.args[2] == :(_) && typeof(x.args[3]) <: Integer
            Expr(:call, :val!, mss, x.args[3])
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
