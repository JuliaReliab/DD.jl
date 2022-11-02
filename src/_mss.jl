"""
MSS
"""

#export bdd, header!, var!, node!, not, and, or, xor, imp, ite, todot

"""
prob(forest, f)
"""

function prob(b::MDDForest, f::AbstractNode, pr::Dict{NodeHeader,Vector{Float64}}, value::Tv) where Tv
    cache = Dict{NodeID,Float64}()
    _prob!(b, f, pr, cache, value)
end

function _prob!(b::MDDForest, f::AbstractTerminal, pr::Dict{NodeHeader,Vector{Float64}}, cache::Dict{NodeID,Float64}, value::Tv) where Tv
    f.value == value && return 1.0
    return 0.0
end

function _prob!(b::MDDForest, f::Node, pr::Dict{NodeHeader,Vector{Float64}}, cache::Dict{NodeID,Float64}, value::Tv) where Tv
    get(cache, f.id) do
        res = 0.0
        fv = pr[f.header]
        for i = eachindex(f.header.domains)
            res += fv[i] * _prob!(b, f.nodes[i], pr, cache, value)
        end
        cache[f.id] = res
    end
end

"""
getbounds(forest, f, lower, upper)
"""

function getbounds(b::MDDForest, f::AbstractNode, lower::Vector{ValueT}, upper::Vector{ValueT})
    cache = Dict()
    _getbounds!(b, f, lower, upper, cache)
end

function _getbounds!(b::MDDForest, f::Terminal{ValueT}, ::Vector{ValueT}, ::Vector{ValueT}, cache)
    [f.value, f.value]
end

function _getbounds!(b::MDDForest, f::Terminal{Undetermined}, ::Vector{ValueT}, ::Vector{ValueT}, cache)
    [Undetermined(), Undetermined()]
end

function _getbounds!(b::MDDForest, f::Node, lower::Vector{ValueT}, upper::Vector{ValueT}, cache)
    get(cache, f.id) do
        m = Any[Undetermined(), Undetermined()]
        for i = f.header.index[lower[f.header.level]]:f.header.index[upper[f.header.level]]
            lres, ures = _getbounds!(b, f.nodes[i], lower, upper, cache)
            if lres != Undetermined() && (m[1] == Undetermined() || lres < m[1])
                m[1] = lres
            end
            if ures != Undetermined() && (m[2] == Undetermined() || ures > m[2])
                m[2] = ures
            end
        end
        cache[f.id] = m
    end
end

"""
getmaxbounds2(forest, f, lower, upper)
"""

function getbounds3(b::MDDForest, f::AbstractNode, lower::Vector{ValueT}, upper::Vector{ValueT}, id)
    result1 = []
    result2 = []
    _getidnode!(b, f, lower, upper, id, Set(), result1, result2)
    # println(result1)
    # println(result2)
    if length(result1) == 0 && length(result2) == 0
        [lower[id], upper[id]]
    else
        cache = Dict()
        m = [65535, -1]
        for x = result1
            _getbounds3!(b, x, lower, upper, cache)
            for v = lower[x.header.level]:upper[x.header.level]
                i = x.header.index[v]
                tmp = cache[x.nodes[i].id]
                if tmp[1] != Undetermined()
                    m[1] = min(m[1], v + tmp[1])
                    m[2] = max(m[2], v + tmp[2])
                end
            end
            # println(todot(b, x))
        end
        # println("m", m)
        for x = result2
            tmp = _getbounds3!(b, x, lower, upper, cache)
            if tmp[1] != Undetermined()
                m[1] = min(m[1], lower[id] + tmp[1])
                m[2] = max(m[2], upper[id] + tmp[2])
            end
        end
    end
    m
end

function _getidnode!(b::MDDForest, f::Node, lower::Vector{ValueT}, upper::Vector{ValueT}, id, visited, result1, result2)
    if in(f.id, visited)
        return
    end
    if f.header.level == id
        push!(visited, f.id)
        push!(result1, f)
        return
    end
    if f.header.level < id
        push!(visited, f.id)
        push!(result2, f)
        return
    end
    for v = lower[f.header.level]:upper[f.header.level]
        i = f.header.index[v]
        _getidnode!(b, f.nodes[i], lower, upper, id, visited, result1, result2)
        push!(visited, f.id)
    end
end

function _getidnode!(b::MDDForest, f::Terminal{ValueT}, lower::Vector{ValueT}, upper::Vector{ValueT}, id, visited, result1, result2)
    if in(f.id, visited)
        return
    end
    push!(visited, f.id)
    push!(result2, f)
end

function _getidnode!(b::MDDForest, f::Terminal{Undetermined}, lower::Vector{ValueT}, upper::Vector{ValueT}, id, visited, result1, result2)
    return
end

function _getbounds3!(b::MDDForest, f::Terminal{ValueT}, ::Vector{ValueT}, ::Vector{ValueT}, cache)
    get(cache, f.id) do
        cache[f.id] = [f.value, f.value]
    end
end

function _getbounds3!(b::MDDForest, f::Terminal{Undetermined}, ::Vector{ValueT}, ::Vector{ValueT}, cache)
    get(cache, f.id) do
        cache[f.id] = [Undetermined(), Undetermined()]
    end
end

function _getbounds3!(b::MDDForest, f::Node, lower::Vector{ValueT}, upper::Vector{ValueT}, cache)
    get(cache, f.id) do
        m = Any[Undetermined(), Undetermined()]
        for i = f.header.index[lower[f.header.level]]:f.header.index[upper[f.header.level]]
            lres, ures = _getbounds3!(b, f.nodes[i], lower, upper, cache)
            if lres != Undetermined() && (m[1] == Undetermined() || lres < m[1])
                m[1] = lres
            end
            if ures != Undetermined() && (m[2] == Undetermined() || ures > m[2])
                m[2] = ures
            end
        end
        cache[f.id] = m
    end
end


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

function var!(mss::MSS{Ts,Tx}, name::Ts, domain::AbstractVector{Tx}) where {Ts,Tx}
    x = var!(mss.dd, name, length(mss.vars)+1, domain)
    mss.vars[name] = MSSVariable{Ts,Tx}(name, domain, x.header, x)
    x
end

function val!(mss::MSS{Ts,Tx}, value::Tx) where {Ts,Tx}
    Terminal(mss.dd, value)
end

## macro

"""
Example

## definition of function
@gate G1(a, b) begin
  if a == 0 || b == 0
    0
  else
    b
  end
end

@gate G2(a, b) begin
  match(
      a == 0 && b == 0 => 0,
      a == 0 || b == 0 => 1,
      a == 2 || b == 2 => 3,
      _ => 2
  )
end

Sx = G2(dd, B, C)
SS = G1(dd, A, Sx)
"""

function _cond(mss, s::Any)
    s
end

function _cond(mss, s::Symbol)
    if s == :None
        Expr(:call, :Terminal, mss)
    else
        s
    end
end

function _cond(mss, s::Integer)
    Expr(:call, :Terminal, mss, s)
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
        elseif x.args[1] == :(+)
            Expr(:call, :plus!, mss, [_cond(mss, u) for u = x.args[2:end]]...)
        elseif x.args[1] == :(-)
            Expr(:call, :minus!, mss, [_cond(mss, u) for u = x.args[2:end]]...)
        elseif x.args[1] == :(*)
            Expr(:call, :mul!, mss, [_cond(mss, u) for u = x.args[2:end]]...)
        else
            throw(ErrorException("Function expression: Available functions are ==, !=, >=, <=, >, <, max, min, +, -, *"))
        end
    elseif Meta.isexpr(x, :(&&))
        Expr(:call, :and!, mss, _cond(mss, x.args[1]), _cond(mss, x.args[2]))
    elseif Meta.isexpr(x, :(||))
        Expr(:call, :or!, mss, _cond(mss, x.args[1]), _cond(mss, x.args[2]))
    else
        x
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

function _match(mss, b::Expr)
    if Meta.isexpr(b, :block)
        match = [v for v = b.args if Meta.isexpr(v, :call) && v.args[1] == :(=>)]
    end
    _branch(mss, match)
end
    
macro mss(s, b)
    esc(_mss(s, b))
end
