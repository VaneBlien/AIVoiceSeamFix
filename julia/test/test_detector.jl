# test_detector.jl
# 小波断裂检测测试

using Test
import AIVoiceSeamFix.Algorithms.Repair.WaveletDetector: detect_breaks_wavevel
import AIVoiceSeamFix.Algorithms.Common.Kernels: gaussian_kernel

# ============================================================
# gaussian_kernel
# ============================================================

@testset "gaussian_kernel" begin
    @testset "basic properties" begin
        k = gaussian_kernel(10, 3.0)
        @test length(k) == 21
        @test k[11] ≈ maximum(k)  # 中心最大
        @test sum(k) ≈ 1.0  # 归一化
        @test all(k .> 0)  # 全正
        @test k[1] ≈ k[end]  # 对称
    end

    @testset "sigma effect" begin
        k_narrow = gaussian_kernel(10, 1.0)
        k_wide = gaussian_kernel(10, 5.0)
        @test maximum(k_narrow) > maximum(k_wide)  # 窄核峰值更高
    end

    @testset "edge cases" begin
        k = gaussian_kernel(0, 1.0)
        @test length(k) == 1
        @test k[1] ≈ 1.0

        @test_throws ArgumentError gaussian_kernel(-1, 1.0)
        @test_throws ArgumentError gaussian_kernel(5, 0.0)
    end
end

# ============================================================
# detect_breaks_wavelet
# ============================================================

@testset "detect_breaks_wavelet" begin
    @testset "clean signal (no breaks)" begin
        sr = 44100
        t = range(0, 1, length=sr)
        clean = sin.(2π * 440 * t)
        breaks = detect_breaks_wavevel(clean, sr; sensitivity=8.0)
        @test isempty(breaks)
    end

    @testset "artificial seam (step discontinuity)" begin
        sr = 44100
        # 两段不同幅度的正弦波拼接，在中间有一个阶跃
        half = sr ÷ 2
        segment1 = 0.5 .* sin.(2π * 440 * range(0, 0.5, length=half))
        segment2 = 0.8 .* sin.(2π * 880 * range(0, 0.5, length=sr - half))
        joined = vcat(segment1, segment2)

        breaks = detect_breaks_wavevel(joined, sr; sensitivity=4.0)
        @test length(breaks) >= 1
        @test minimum(abs.(breaks .- half)) < sr ÷ 100  # 10ms 内
    end

    @testset "multiple seams" begin
        sr = 44100
        third = sr ÷ 3
        seg1 = 0.3 .* sin.(2π * 220 * range(0, 1/3, length=third))
        seg2 = 1.0 .* sin.(2π * 440 * range(0, 1/3, length=third))
        seg3 = 0.5 .* sin.(2π * 660 * range(0, 1/3, length=sr - 2*third))
        joined = vcat(seg1, seg2, seg3)

        breaks = detect_breaks_wavevel(joined, sr; sensitivity=4.0)
        @test length(breaks) >= 2
    end

    @testset "too short signal" begin
        sr = 44100
        short = rand(100)  # ~2ms
        breaks = detect_breaks_wavevel(short, sr)
        @test isempty(breaks)
    end

    @testset "sensitivity effect" begin
        sr = 44100
        half = sr ÷ 2
        joined = vcat(0.5 .* sin.(2π * 440 * range(0, 0.5, length=half)),
                      0.6 .* sin.(2π * 440 * range(0, 0.5, length=sr-half)))

        # 高灵敏度 → 更容易检测
        breaks_low = detect_breaks_wavevel(joined, sr; sensitivity=2.0)
        breaks_high = detect_breaks_wavevel(joined, sr; sensitivity=20.0)
        @test length(breaks_low) >= length(breaks_high)
    end
end

println("✅ All detector tests passed!")