"""
MSS
"""

module MultiState

import ..MDD

"""
Multi-State System (MSS)
"""

mutable struct MSS
    b::MDD.MDDForest
    vars::Dict{Symbol,MDD.AbstractNode}

    function MSS()
        b = MDD.mdd()
        h = Dict{Symbol,MDD.AbstractNode}()
        new(b, h)
    end
end

function mssvar!(mss::MSS, name::Symbol, domains::AbstractVector{MDD.ValueT})
    x = MDD.var!(mss.b, name, length(mss.vars)+1, domains)
    mss.vars[name] = x
    x
end

MDD.mdd(mss::MSS) = mss.b

"""
prob(forest, f)
"""

function prob(f::MDD.AbstractNode, pr::Dict{Symbol,Vector{Float64}}, value::MDD.ValueT)
    cache = Dict{MDD.NodeID,Float64}()
    _prob!(f, pr, cache, value)
end

function _prob!(f::MDD.AbstractTerminal, pr::Dict{Symbol,Vector{Float64}},
    cache::Dict{MDD.NodeID,Float64}, value::MDD.ValueT)
    f.value == value && return 1.0
    return 0.0
end

function _prob!(f::MDD.Node, pr::Dict{Symbol,Vector{Float64}},
    cache::Dict{MDD.NodeID,Float64}, value::MDD.ValueT)
    get(cache, f.id) do
        res = 0.0
        fv = pr[f.header.label]
        for i = eachindex(f.header.domains)
            res += fv[i] * _prob!(f.nodes[i], pr, cache, value)
        end
        cache[f.id] = res
    end
end

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

end
