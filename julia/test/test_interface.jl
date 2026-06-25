# test_interface.jl
# 算法接口合规性测试

using Test
using AIVoiceSeamFix.Types
using AIVoiceSeamFix.Params
using AIVoiceSeamFix.Interface

# 显式导入要扩展的函数
import AIVoiceSeamFix.Interface:
    algorithm_id,
    algorithm_name,
    algorithm_mode,
    channel_policy,
    parameter_specs,
    process

# ============================================================
# Mock 算法
# ============================================================

struct MockRepairAlgorithm <: AbstractRepairAlgorithm end

algorithm_id(::MockRepairAlgorithm) = "mock_repair"
algorithm_name(::MockRepairAlgorithm) = "Mock Repair"
algorithm_mode(::MockRepairAlgorithm) = "repair"
channel_policy(::MockRepairAlgorithm) = :mono

function parameter_specs(::MockRepairAlgorithm)
    return [
        ParamSpec(
            name = :strength,
            type = Float64,
            default = 0.5,
            label = "强度",
            min = 0.0,
            max = 1.0,
            step = 0.1,
        ),
    ]
end

function process(
    ::MockRepairAlgorithm,
    audio::AudioBuffer,
    params::Dict{Symbol, Any},
    ctx::AlgorithmContext,
)::AlgorithmResult
    return AlgorithmResult(
        audio = audio,
        regions = RepairRegion[],
        report = Dict("algorithm_id" => "mock_repair", "status" => "ok"),
    )
end

# ---- MockJoin ----

struct MockJoinAlgorithm <: AbstractJoinAlgorithm end

algorithm_id(::MockJoinAlgorithm) = "mock_join"
algorithm_name(::MockJoinAlgorithm) = "Mock Join"
algorithm_mode(::MockJoinAlgorithm) = "join"
# 不定义 channel_policy 和 parameter_specs，测试默认值

function process(
    ::MockJoinAlgorithm,
    audios::Vector{AudioBuffer},
    params::Dict{Symbol, Any},
    ctx::AlgorithmContext,
)::AlgorithmResult
    return AlgorithmResult(
        audio = audios[1],
        regions = RepairRegion[],
        report = Dict("algorithm_id" => "mock_join", "segments" => length(audios)),
    )
end

# ============================================================
# 接口合规性
# ============================================================

@testset "Interface compliance" begin
    @testset "abstract type hierarchy" begin
        @test MockRepairAlgorithm <: AbstractRepairAlgorithm
        @test MockRepairAlgorithm <: AbstractAudioAlgorithm
        @test MockJoinAlgorithm <: AbstractJoinAlgorithm
        @test MockJoinAlgorithm <: AbstractAudioAlgorithm
    end

    @testset "required methods" begin
        repair = MockRepairAlgorithm()
        join = MockJoinAlgorithm()

        @test algorithm_id(repair) == "mock_repair"
        @test algorithm_name(repair) == "Mock Repair"
        @test algorithm_version(repair) == v"0.1.0"
        @test algorithm_mode(repair) == "repair"
        @test channel_policy(repair) == :mono

        @test algorithm_id(join) == "mock_join"
        @test algorithm_name(join) == "Mock Join"
        @test algorithm_mode(join) == "join"
        # 默认值
        @test channel_policy(join) == :mono
    end

    @testset "parameter_specs" begin
        specs = parameter_specs(MockRepairAlgorithm())
        @test length(specs) == 1
        @test specs[1].name == :strength
        @test specs[1].default == 0.5

        # 未定义的返回默认空列表
        specs_default = parameter_specs(MockJoinAlgorithm())
        @test specs_default == ParamSpec[]
    end

    @testset "algorithm_info" begin
        info = algorithm_info(MockRepairAlgorithm())
        @test info["id"] == "mock_repair"
        @test info["name"] == "Mock Repair"
        @test info["mode"] == "repair"
        @test info["channel_policy"] == "mono"
        @test length(info["params"]) == 1
        @test info["params"][1]["name"] == "strength"
    end

    @testset "AlgorithmContext" begin
        ctx = AlgorithmContext()
        @test ctx.temp_dir == ""
        @test ctx.cancel_requested == false

        ctx2 = AlgorithmContext(temp_dir="/tmp", request_id="123")
        @test ctx2.temp_dir == "/tmp"
        @test ctx2.request_id == "123"
    end
end

# ============================================================
# process
# ============================================================

@testset "process" begin
    repair = MockRepairAlgorithm()
    join = MockJoinAlgorithm()
    audio = AudioBuffer(rand(1000), 44100)
    ctx = AlgorithmContext()

    @testset "repair process" begin
        result = process(repair, audio, Dict{Symbol, Any}(), ctx)
        @test result isa AlgorithmResult
        @test result.audio === audio
        @test result.report["status"] == "ok"
    end

    @testset "join process" begin
        result = process(join, [audio, audio], Dict{Symbol, Any}(), ctx)
        @test result isa AlgorithmResult
        @test result.report["segments"] == 2
    end
end

# ============================================================
# 未实现算法应报 MethodError（不是 ErrorException）
# ============================================================

@testset "unimplemented interface errors" begin
    struct BadAlgorithm <: AbstractRepairAlgorithm end
    audio = AudioBuffer(rand(100), 44100)
    ctx = AlgorithmContext()

    @testset "algorithm_id not implemented" begin
        @test_throws MethodError algorithm_id(BadAlgorithm())
    end

    @testset "algorithm_name not implemented" begin
        @test_throws MethodError algorithm_name(BadAlgorithm())
    end

    @testset "algorithm_mode not implemented" begin
        @test_throws MethodError algorithm_mode(BadAlgorithm())
    end

    @testset "process not implemented" begin
        @test_throws MethodError process(BadAlgorithm(), audio, Dict{Symbol, Any}(), ctx)
    end
end

println("✅ All interface tests passed!")