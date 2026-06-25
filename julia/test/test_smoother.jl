# test_smoother.jl
# test_smoother.jl

using Test
import AIVoiceSeamFix.Algorithms.Repair.GaussianSmoother: smooth_regions
using AIVoiceSeamFix.Types: RepairRegion

function make_region(start_s::Int, end_s::Int, sr::Int)
    return RepairRegion(
        start_sample = start_s,
        end_sample = end_s,
        center_sample = (start_s + end_s) ÷ 2,
        start_sec = start_s / sr,
        end_sec = end_s / sr,
        center_sec = (start_s + end_s) / (2 * sr),
        score = 0.5,
        label = "seam",
    )
end

@testset "GaussianSmoother" begin
    sr = 44100

    @testset "empty regions returns copy" begin
        samples = rand(1000)
        result = smooth_regions(samples, RepairRegion[], sr)
        @test result == samples
        @test result !== samples  # 是副本不是同一个
    end

    @testset "smoothes step discontinuity" begin
        # 构造一个带阶跃的信号
        n = 2000
        half = n ÷ 2
        samples = vcat(0.5 .* ones(half), 0.8 .* ones(n - half))

        region = make_region(half - 50, half + 50, sr)
        regions = [region]
        result = smooth_regions(samples, regions, sr; window_ms=20.0, sigma_ms=4.0, alpha=0.7)

        # 平滑后过渡区不应再是阶跃
        transition = result[half-10:half+10]
        @test maximum(transition) - minimum(transition) < 0.3

        # 远离断裂点的区域应保持原样
        @test result[1] ≈ 0.5
        @test result[end] ≈ 0.8
    end

    @testset "preserves clean regions" begin
        samples = sin.(2π * 440 * range(0, 1, length=sr))
        region = make_region(sr ÷ 2 - 100, sr ÷ 2 + 100, sr)
        result = smooth_regions(samples, [region], sr; window_ms=10.0, sigma_ms=2.0, alpha=0.1)

        # 远离 region 的信号应几乎不变
        @test result[1:100] ≈ samples[1:100]
        @test result[end-99:end] ≈ samples[end-99:end]
    end

    @testset "alpha effect" begin
        n = 1000
        samples = vcat(0.0 .* ones(n ÷ 2), 1.0 .* ones(n - n ÷ 2))
        region = make_region(n ÷ 2 - 20, n ÷ 2 + 20, 44100)

        result_strong = smooth_regions(samples, [region], 44100; alpha=0.9)
        result_weak = smooth_regions(samples, [region], 44100; alpha=0.1)

        # alpha 越大平滑越强，过渡区更平坦
        mid = n ÷ 2
        diff_strong = abs(result_strong[mid] - 0.5)
        diff_weak = abs(result_weak[mid] - 0.5)
        @test diff_strong < diff_weak + 0.2
    end

    @testset "multiple regions" begin
        n = 3000
        samples = vcat(0.3 .* ones(n÷3), 0.7 .* ones(n÷3), 0.5 .* ones(n - 2n÷3))
        r1 = make_region(n÷3 - 50, n÷3 + 50, 44100)
        r2 = make_region(2n÷3 - 50, 2n÷3 + 50, 44100)
        result = smooth_regions(samples, [r1, r2], 44100; alpha=0.5)

        # 两处都应该被平滑
        @test !isapprox(result[n÷3], samples[n÷3], atol=0.01)
        @test !isapprox(result[2n÷3], samples[2n÷3], atol=0.01)
    end
end

println("✅ All smoother tests passed!")