# test_runner.jl
# Runner 统一运行入口测试

using Test
using AIVoiceSeamFix.Types
using AIVoiceSeamFix.Params
using AIVoiceSeamFix.Interface
using AIVoiceSeamFix.Registry
using AIVoiceSeamFix.Runner
using AIVoiceSeamFix.Errors

# ============================================================
# Mock 算法（带完整 process 实现）
# ============================================================

struct TestRepair <: AbstractRepairAlgorithm end
algorithm_id(::TestRepair) = "test_repair"
algorithm_name(::TestRepair) = "Test Repair"
algorithm_mode(::TestRepair) = "repair"

function parameter_specs(::TestRepair)
    return [
        ParamSpec(name=:sensitivity, type=Float64, default=8.0, label="Sens",
                  min=1.0, max=20.0),
    ]
end

function process(
    ::TestRepair,
    audio::AudioBuffer,
    params::Dict{Symbol, Any},
    ctx::AlgorithmContext,
)::AlgorithmResult
    sensitivity = get(params, :sensitivity, 8.0)
    return AlgorithmResult(
        audio = audio,
        regions = RepairRegion[],
        report = Dict(
            "algorithm_id" => "test_repair",
            "sensitivity" => sensitivity,
            "request_id" => ctx.request_id,
        ),
    )
end

struct TestJoin <: AbstractJoinAlgorithm end
algorithm_id(::TestJoin) = "test_join"
algorithm_name(::TestJoin) = "Test Join"
algorithm_mode(::TestJoin) = "join"

function process(
    ::TestJoin,
    audios::Vector{AudioBuffer},
    params::Dict{Symbol, Any},
    ctx::AlgorithmContext,
)::AlgorithmResult
    return AlgorithmResult(
        audio = audios[1],
        regions = RepairRegion[],
        report = Dict(
            "algorithm_id" => "test_join",
            "segments" => length(audios),
            "request_id" => ctx.request_id,
        ),
    )
end

# ============================================================
# 测试 setup
# ============================================================

function setup_registry()
    reg = AlgorithmRegistry()
    register_algorithm!(reg, TestRepair())
    register_algorithm!(reg, TestJoin())
    return reg
end

function make_audio(n_samples=1000, sr=44100)
    return AudioBuffer(rand(n_samples), sr)
end

# ============================================================
# run_repair_algorithm
# ============================================================

@testset "run_repair_algorithm" begin
    reg = setup_registry()
    audio = make_audio()
    ctx = AlgorithmContext(request_id="req-001")

    @testset "successful run" begin
        params = Dict{Symbol, Any}(:sensitivity => 10.0)
        result = run_repair_algorithm(reg, "test_repair", audio, params, ctx)

        @test result isa AlgorithmResult
        @test result.audio === audio
        @test result.report["algorithm_id"] == "test_repair"
        @test result.report["sensitivity"] == 10.0
        @test result.report["request_id"] == "req-001"
    end

    @testset "with default params" begin
        result = run_repair_algorithm(reg, "test_repair", audio, Dict{Symbol, Any}(), ctx)
        @test result.report["sensitivity"] == 8.0  # default
    end

    @testset "unknown algorithm" begin
        @test_throws UnknownAlgorithmError run_repair_algorithm(
            reg, "nonexistent", audio, Dict{Symbol, Any}(), ctx)
    end

    @testset "wrong mode (join called as repair)" begin
        @test_throws ErrorException run_repair_algorithm(
            reg, "test_join", audio, Dict{Symbol, Any}(), ctx)
    end
end

# ============================================================
# run_join_algorithm
# ============================================================

@testset "run_join_algorithm" begin
    reg = setup_registry()
    audio1 = make_audio(500)
    audio2 = make_audio(500, 44100)
    audios = [audio1, audio2]
    ctx = AlgorithmContext(request_id="req-002")

    @testset "successful run" begin
        result = run_join_algorithm(reg, "test_join", audios, Dict{Symbol, Any}(), ctx)

        @test result isa AlgorithmResult
        @test result.report["algorithm_id"] == "test_join"
        @test result.report["segments"] == 2
        @test result.report["request_id"] == "req-002"
    end

    @testset "unknown algorithm" begin
        @test_throws UnknownAlgorithmError run_join_algorithm(
            reg, "nonexistent", audios, Dict{Symbol, Any}(), ctx)
    end

    @testset "wrong mode (repair called as join)" begin
        @test_throws ErrorException run_join_algorithm(
            reg, "test_repair", audios, Dict{Symbol, Any}(), ctx)
    end
end

# ============================================================
# AlgorithmContext 取消机制
# ============================================================

@testset "AlgorithmContext cancel flag" begin
    reg = setup_registry()
    audio = make_audio()
    ctx = AlgorithmContext(cancel_requested=true)

    # 注意：当前 mock 算法不检查取消标志，此处验证 ctx 字段正确传递
    result = run_repair_algorithm(reg, "test_repair", audio, Dict{Symbol, Any}(), ctx)
    @test result.report["request_id"] == ""
    @test ctx.cancel_requested == true
end

println("✅ All runner tests passed!")