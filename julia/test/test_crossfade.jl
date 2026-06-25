# test_crossfade.jl
# test_crossfade.jl

using Test
using AIVoiceSeamFix
import AIVoiceSeamFix.Algorithms.Join.EqualPowerCrossfadeJoin: EqualPowerCrossfadeJoinAlgorithm
import AIVoiceSeamFix: process, algorithm_id, run_join_algorithm

function make_tone(freq, duration, sr=44100)
    n = Int(sr * duration)
    return AudioBuffer(sin.(2π * freq * range(0, duration, length=n)), sr)
end

@testset "EqualPowerCrossfadeJoin" begin
    alg = EqualPowerCrossfadeJoinAlgorithm()

    @testset "algorithm identity" begin
        @test algorithm_id(alg) == "equal_power_crossfade_join"
        @test AIVoiceSeamFix.algorithm_mode(alg) == "join"
        @test length(AIVoiceSeamFix.parameter_specs(alg)) == 1
    end

    @testset "join two segments" begin
        a1 = make_tone(440, 1.0)
        a2 = make_tone(880, 1.0)
        ctx = AlgorithmContext()
        result = process(alg, [a1, a2], Dict{Symbol, Any}(:fade_ms => 25.0), ctx)
        @test result isa AlgorithmResult
        @test result.report["segments"] == 2
        @test result.audio.sample_rate == 44100
    end

    @testset "join three segments" begin
        segments = [make_tone(220, 0.5), make_tone(440, 0.5), make_tone(880, 0.5)]
        ctx = AlgorithmContext()
        result = process(alg, segments, Dict{Symbol, Any}(), ctx)
        @test result.report["segments"] == 3
    end

    @testset "no clicks at seams" begin
        a1 = make_tone(440, 1.0)
        a2 = make_tone(880, 1.0)
        ctx = AlgorithmContext()
        result = process(alg, [a1, a2], Dict{Symbol, Any}(:fade_ms => 50.0), ctx)

        # 在接缝附近检查不应有突变
        seam = length(a1.samples) - Int(0.05 * 44100)  # 50ms 交叉淡化
        nearby = result.audio.samples[seam-10:seam+10, 1]
        diffs = diff(nearby[:, 1])
        @test maximum(abs.(diffs)) < 0.5
    end

    @testset "Registry + Runner integration" begin
        reg = AlgorithmRegistry()
        register_algorithm!(reg, EqualPowerCrossfadeJoinAlgorithm())

        a1 = make_tone(440, 0.5)
        a2 = make_tone(880, 0.5)
        ctx = AlgorithmContext()
        result = run_join_algorithm(reg, "equal_power_crossfade_join", [a1, a2], Dict{Symbol, Any}(), ctx)
        @test result.report["segments"] == 2
    end
end

println("✅ All crossfade tests passed!")