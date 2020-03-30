export domain

"""
DDDomain{Ti}

A domain of DD variable. A field `domain` is an instance of Vector.
"""

struct DDDomain{Ti}
    domain::Vector{Ti}
end

"""
domain(d)
Return the DD domain with a given d that is either UnitRange or Vector.
"""

function domain(domain::UnitRange{Ti}) where Ti
    DDDomain{Ti}(collect(domain))
end

function domain(domain::Vector{Ti}) where Ti
    DDDomain{Ti}(domain)
end

"""
size(domain)
Return a size of domain.
"""

function Base.size(domain::DDDomain{Ti}) where Ti
    length(domain.domain)
end

"""
getindex(domain)
Return an element of domain.
"""

function Base.getindex(domain::DDDomain{Ti}, i::Index) where {Ti,Index}
    domain.domain[i]
end
