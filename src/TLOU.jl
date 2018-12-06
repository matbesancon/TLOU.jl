module TLOU

import RecipesBase
using StaticArrays: SVector

"""
Information from the higher level decision: TLOU pricing structure
"""
struct Pricing{N1,N2}
    K::Float64
    C_L::SVector{N1,Float64}
    C_H::SVector{N2,Float64}
    piL::SVector{N1,Float64}
    piH::SVector{N2,Float64}
    function Pricing(K::Real,C_L::SVector{N1,Float64},C_H::SVector{N2,Float64},piL::SVector{N1,Float64},piH::SVector{N2,Float64}) where {N1,N2}
        new{N1,N2}(K, C_L, C_H, piL, piH)
    end
end

"""
Construct Pricing from NTuples
"""
function Pricing(K::Real,C_L::NTuple{N1,T},C_H::NTuple{N2,T},piL::NTuple{N1,T},piH::NTuple{N2,T}) where {N1,N2,T<:Real}
    return Pricing(K,SVector(C_L),SVector(C_H),SVector(piL),SVector(piH))
end

"""
Calling a pricing directly on a capacity value and consumption returns the
corresponding cost of energy.
A capacity of 0 always corresponds the base price 1.0
"""
function (p::Pricing{N1,N2})(c, x) where {N1,N2}
    if x <= c
        idx = price_segment(p, c, Val{:low}())
        price = idx > 0 ? p.piL[idx] : 1.0
        p.K*c + price * x
    else
        idx = price_segment(p, c, Val{:high}())
        price = idx > 0 ? p.piH[idx] : 1.0
        p.K*c + price * x
    end
end

"""
Returns the price value corresponding to a price_segment
Allowed symbols are:
* :low for lower price
* :high for higher price
* :both to get a tuple (low_price, high_price)
"""
function price_value(p::Pricing{N1,N2}, c, s::Symbol) where {N1,N2}
    price_value(p, c, Val(s))
end

function price_value(p::Pricing{N1,N2}, c, ::Val{:low}) where {N1,N2}
    ps = price_segment(p, c, Val{:low}())
    ps == 0 ? 1.0 : p.piL[ps]
end

function price_value(p::Pricing{N1,N2}, c, ::Val{:high}) where {N1,N2}
    ps = price_segment(p, c, Val{:high}())
    ps == 0 ? 1.0 : p.piH[ps]
end

function price_value(p::Pricing{N1,N2}, c, ::Val{:both}) where {N1,N2}
    (psL, psH) = price_segment(p, c, Val{:both}())
    (psL == 0 ? 1.0 : p.piL[psL], psH == 0 ? 1.0 : p.piH[psH])
end

"""
Returns the segment in πL/πH correesponding to a capacity.
Segment 0 corresponds to the baseline, others to an index
in the corresponding price vector.
Allowed symbols are:
* :low for lower price
* :high for higher price
* :both to get a tuple (low_idx, high_idx)
"""
function price_segment(p::Pricing{N1,N2}, c, s::Symbol) where {N1,N2}
    price_segment(p, c, Val(s))
end

function price_segment(p::Pricing{N1,N2}, c, ::Val{:low}) where {N1,N2}
    idxlow = 1
    while idxlow <= N1
        if p.C_L[idxlow] > c
            break
        end
        idxlow += 1
    end
    return idxlow - 1
end

function price_segment(p::Pricing{N1,N2}, c, ::Val{:high}) where {N1,N2}
    idxhigh = 1
    while idxhigh <= N2
        if p.C_H[idxhigh] > c
            break
        end
        idxhigh += 1
    end
    return idxhigh - 1
end

function price_segment(p::Pricing{N1,N2}, c, ::Val{:both}) where {N1,N2}
    (price_segment(p, c, Val{:low}()), price_segment(p, c, Val{:high}()))
end

"""
Represent a TLOU pricing graphically.
mcoeff adjusts how far the curves are represented after last jump point
"""
function RecipesBase.plot(pr::Pricing{N1,N2}; mcoeff = 1.1) where {N1,N2}
    m = max(maximum(pr.C_L),maximum(pr.C_H)) * mcoeff ## slightly larger than last
    p = RecipesBase.plot(
        [0.0,m], [0.0,m*pr.K],
        label = "Booking fee", color = :orange, alpha = 0.5
    )
    RecipesBase.plot!(p,
        [0.0,max(first(pr.C_L),first(pr.C_H))], [1.0, 1.0],
        color = :black, line = :dot
    )
    RecipesBase.plot!(p,
        [first(pr.C_L),first(pr.C_L)], [1.0, first(pr.piL)],
        color = :blue, line = :dot
    )
    RecipesBase.plot!(p,
        [first(pr.C_H),first(pr.C_H)], [1.0, first(pr.piH)],
        color = :red, line = :dot
    )
    for idx in Base.OneTo(N1-1)
        RecipesBase.plot!(p,
            pr.C_L[idx:idx+1], [pr.piL[idx],pr.piL[idx]],
            color = :blue, line = :dot
        )
        RecipesBase.plot!(p,
            [pr.C_L[idx+1],pr.C_L[idx+1]], [pr.piL[idx:idx+1]],
            color = :blue, line = :dot
        )
    end
    for idx in Base.OneTo(N2-1)
        RecipesBase.plot!(p,
            pr.C_H[idx:idx+1], [pr.piH[idx],pr.piH[idx]],
            color = :red, line = :dot
        )
        RecipesBase.plot!(p,
            [pr.C_H[idx+1],pr.C_H[idx+1]], [pr.piH[idx:idx+1]],
            color = :red, line = :dot
        )
    end
    RecipesBase.plot!(p,
        [last(pr.C_L), m], [last(pr.piL),last(pr.piL)],
        color = :blue, line = :dot
    )
    RecipesBase.plot!(p,
        [last(pr.C_H), m], [last(pr.piH),last(pr.piH)],
        color = :red, line = :dot
    )
    return p
end

"""
Captures both higher and lower level decisions of the TLOU
"""
struct Decision{N1,N2}
    p::Pricing{N1,N2}
    c::Float64
    Decision(p::Pricing{N1,N2},c::Real) where {N1,N2} = new{N1,N2}(p,c)
end

end # module
