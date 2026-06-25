# test_pipeline.jl
# test_pipeline.jl
# 端到端修复流程测试

using Test
using AIVoiceSeamFix
import AIVoiceSeamFix.Algorithms.Repair.WaveletGaussianRepair: WaveletGaussianRepairAlgorithm
import AIVoiceSeamFix: process, algorithm_id, run_repair_algorithm

function make_seamed_audio(sr=44100, duration=2.0)
    n = Int(sr * duration)
    half = n ÷ 2
    seg1 = 0.5 .* sin.(2π * 440 .* range(0, 0.5, length=half))
    seg2 = 0.8 .* sin.(2π * 880 .* range(0, 0.5, length=n - half))
    samples = vcat(seg1, seg2)
    return AudioBuffer(samples, sr)
end

@testset "WaveletGaussianRepair" begin
    alg = WaveletGaussianRepairAlgorithm()

    @testset "algorithm identity" begin
        @test algorithm_id(alg) == "wavelet_gaussian_repair"
        @test AIVoiceSeamFix.algorithm_name(alg) == "Wavelet + Gaussian Repair"
        @test AIVoiceSeamFix.algorithm_mode(alg) == "repair"
        @test AIVoiceSeamFix.channel_policy(alg) == :mono
        @test length(AIVoiceSeamFix.parameter_specs(alg)) == 6
    end

    @testset "process returns AlgorithmResult" begin
        audio = make_seamed_audio()
        params = Dict{Symbol, Any}()
        ctx = AlgorithmContext()

        result = process(alg, audio, params, ctx)
        @test result isa AlgorithmResult
        @test result.audio isa AudioBuffer
        @test result.audio.sample_rate == audio.sample_rate
        @test size(result.audio.samples, 1) == size(audio.samples, 1)
        @test result.report["algorithm_id"] == "wavelet_gaussian_repair"
    end

    @testset "detects and smooths seams" begin
        audio = make_seamed_audio()
        ctx = AlgorithmContext()
        result = process(alg, audio, Dict(:sensitivity => 4.0), ctx)

        # 应该检测到至少一个断裂点
        @test result.report["detected_points"] >= 1
        @test result.report["detected_regions"] >= 1
    end

    @testset "clean signal produces no regions" begin
        sr = 44100
        t = range(0, 2, length=2sr)
        clean = AudioBuffer(sin.(2π * 440 .* t), sr)
        ctx = AlgorithmContext()
        result = process(alg, clean, Dict{Symbol, Any}(), ctx)

        @test result.report["detected_points"] == 0
        @test result.report["detected_regions"] == 0
    end

    @testset "custom params are respected" begin
        audio = make_seamed_audio()
        ctx = AlgorithmContext()
        params = Dict{Symbol, Any}(
            :sensitivity => 10.0,
            :alpha => 0.3,
        )
        result = process(alg, audio, params, ctx)
        @test result.report["params"]["sensitivity"] == 10.0
        @test result.report["params"]["alpha"] == 0.3
    end

    @testset "invalid param throws" begin
        audio = make_seamed_audio()
        ctx = AlgorithmContext()
        @test_throws InvalidParamsError process(alg, audio, Dict(:sensitivity => 0.0), ctx)
    end
end

@testset "Registry + Runner integration" begin
    # 激活全局 Registry
    reg = AlgorithmRegistry()
    register_algorithm!(reg, WaveletGaussianRepairAlgorithm())

    audio = make_seamed_audio()
    ctx = AlgorithmContext()

    result = run_repair_algorithm(reg, "wavelet_gaussian_repair", audio, Dict{Symbol, Any}(), ctx)
    @test result isa AlgorithmResult
    @test result.report["algorithm_id"] == "wavelet_gaussian_repair"
end

println("✅ All pipeline tests passed!")