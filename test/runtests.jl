using Test

import TLOU

const pr = TLOU.Pricing(
    0.6, # K
    (0.1,0.4,0.6,0.8), #CL
    (0.2,0.5,0.7,0.9, 1.0), #CH
    (0.9,0.7,0.5,0.3), #piL
    (1.1,1.2,1.4,1.6, 2.0)  #piH
)

const test_table = [
    (0.05, 0, 0),
    (0.15, 1, 0),
    (0.20, 1, 1),
    (0.40, 2, 1),
    (0.50, 2, 2),
    (0.60, 3, 2),
    (0.90, 4, 4),
    (1.00, 4, 5),
]

@testset "TLOU.Pricing indexing" begin
    @test pr isa TLOU.Pricing{4,5}
    for (c, idxL, idxH) in test_table
        (iL, iH) = TLOU.price_segment(pr, c, :both)
        @test iL == idxL
        @test iH == idxH
        (pL, pH) = TLOU.price_value(pr, c, :both)
        @test (iL == 0 && pL ≈ 1.0) || pr.piL[iL] ≈ pL
        @test (iH == 0 && pH ≈ 1.0) || pr.piH[iH] ≈ pH
    end
end

@testset "Pricing computation" begin
    for (c, idxL, idxH) in test_table
        xlow =  [0.0, 0.5 * c, 0.9 * c, 1.0 * c]
        xhigh = [1.05c, 1.5 * c, 1.9 * c, 3.0 * c]
        for x in xlow
            cost = pr(c, x)

            @test cost ≈ pr.K*c + x * TLOU.price_value(pr, c, Val{:low}())
        end
        for x in xhigh
            cost = pr(c, x)
            @test cost ≈ pr.K*c + x * TLOU.price_value(pr, c, Val{:high}())
        end
    end
end
