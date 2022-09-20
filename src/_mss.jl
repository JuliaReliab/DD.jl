"""
MSS
"""

#export bdd, header!, var!, node!, not, and, or, xor, imp, ite, todot

mutable struct MSSVariable{Ts,Tx}
    label::Ts
    domain::Vector{Tx}
end

mutable struct MSS{Ts,Tx}
    vars::Dict{Ts,MSSVariable{Ts,Tx}}
    values::Vector{Tx}
    dd::MDDForest
    headers::Dict{Ts,NodeHeader}
    terminals::Dict{Tx,Terminal}
    trueterminal::Terminal
    falseterminal::Terminal

    function MSS(vars::Vector{MSSVariable{Ts,Tx}}, values::Vector{Tx}) where {Ts,Tx}
        dd = MDDForest()
        vv = Dict([x.label => x for x = vars]...)
        headers = Dict([x.label => NodeHeader(i, length(x.domain)) for (i,x) = enumerate(vars)]...)
        terminals = Dict([x => Terminal(dd, x) for x = values]...)
        new{Ts,Tx}(vv, values, dd, headers, terminals, Terminal(dd, true), Terminal(dd, false))
    end
end

function lte!(mss::MSS, x::Ts, v::Tx) where {Ts,Tx}
    n = AbstractNode[]
    domain = mss.vars[x].domain
    for u = domain
        if u <= v
            push!(n, mss.trueterminal)
        else
            push!(n, mss.falseterminal)
        end
    end
    Node(mss.dd, mss.headers[x], n)
end

function gte!(mss::MSS, x::Ts, v::Tx) where {Ts,Tx}
    n = AbstractNode[]
    domain = mss.vars[x].domain
    for u = domain
        if u >= v
            push!(n, mss.trueterminal)
        else
            push!(n, mss.falseterminal)
        end
    end
    Node(mss.dd, mss.headers[x], n)
end

function eq!(mss::MSS, x::Ts, v::Tx) where {Ts,Tx}
    n = AbstractNode[]
    domain = mss.vars[x].domain
    for u = domain
        if u == v
            push!(n, mss.trueterminal)
        else
            push!(n, mss.falseterminal)
        end
    end
    Node(mss.dd, mss.headers[x], n)
end

function neq!(mss::MSS, x::Ts, v::Tx) where {Ts,Tx}
    n = AbstractNode[]
    domain = mss.vars[x].domain
    for u = domain
        if u != v
            push!(n, mss.trueterminal)
        else
            push!(n, mss.falseterminal)
        end
    end
    Node(mss.dd, mss.headers[x], n)
end

function and!(mss::MSS, f, g)
    binapply!(mss.dd, mss.dd.andop, f, g)
end

function or!(mss::MSS, f, g)
    binapply!(mss.dd, mss.dd.orop, f, g)
end

function ifelse!(mss::MSS, f, g, h)
    tmp1 = binapply!(mss.dd, mss.dd.ifop, f, g)
    tmp2 = binapply!(mss.dd, mss.dd.elseop, f, h)
    tmp3 = binapply!(mss.dd, mss.dd.unionop, tmp1, tmp2)
    tmp3
end