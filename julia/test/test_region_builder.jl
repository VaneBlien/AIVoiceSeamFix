# test_region_builder.jl

using Test
import AIVoiceSeamFix.Algorithms.Repair.RegionBuilder: build_regions
using AIVoiceSeamFix.Types: RepairRegion, region_width_samples

@testset "RegionBuilder" begin
    sr = 44100
    total = sr * 2  # 2 秒

    @testset "empty points" begin
        regions = build_regions(Int[], total, sr)
        @test isempty(regions)
    end

    @testset "single point" begin
        regions = build_regions([sr], total, sr; expand_ms=50.0)
        @test length(regions) == 1
        r = regions[1]
        @test r.start_sample > 0
        @test r.end_sample < total
        @test r.start_sample < r.center_sample < r.end_sample
        @test region_width_samples(r) > 0
    end

    @testset "two close points merged" begin
        # 两个点相距 10ms → 应该合并
        p1 = sr ÷ 2
        p2 = p1 + sr ÷ 100  # 10ms 后
        regions = build_regions([p1, p2], total, sr; expand_ms=50.0, merge_ms=80.0)
        @test length(regions) == 1
    end

    @testset "two far points separate" begin
        # 两个点相距 200ms → 不应合并
        p1 = sr ÷ 3
        p2 = (sr * 2) ÷ 3
        regions = build_regions([p1, p2], total, sr; expand_ms=50.0, merge_ms=80.0)
        @test length(regions) == 2
    end

    @testset "boundary clipping" begin
        # 点在边缘时不应越界
        regions = build_regions([100], total, sr; expand_ms=50.0)
        @test regions[1].start_sample >= 0
        @test regions[1].end_sample <= total

        regions_end = build_regions([total - 100], total, sr; expand_ms=50.0)
        @test regions_end[1].end_sample <= total
    end

    @testset "score and label" begin
        regions = build_regions([sr], total, sr)
        @test regions[1].score == 0.5
        @test regions[1].label == "seam"
    end
end

println("✅ All region builder tests passed!")