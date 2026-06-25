# test_types.jl
# Types.jl 和 Params.jl 的单元测试

using Test
using AIVoiceSeamFix.Errors
using AIVoiceSeamFix.Types
using AIVoiceSeamFix.Params

# ============================================================
# AudioMeta
# ============================================================
@testset "AudioMeta" begin
    @testset "default construction" begin
        meta = AudioMeta()
        @test isnothing(meta.source_path)
        @test isnothing(meta.original_format)
        @test meta.has_video == false
        @test meta.duration_sec == 0.0
        @test isempty(meta.extra)
    end

    @testset "custom construction" begin
        meta = AudioMeta(
            source_path = "/path/to/audio.mp3",
            original_format = "mp3",
            has_video = false,
            duration_sec = 3.5,
        )
        @test meta.source_path == "/path/to/audio.mp3"
        @test meta.original_format == "mp3"
        @test meta.duration_sec == 3.5
    end
end

# ============================================================
# AudioBuffer
# ============================================================
@testset "AudioBuffer" begin
    @testset "valid mono from Vector" begin
        samples = rand(100)
        audio = AudioBuffer(samples, 44100)
        @test num_samples(audio) == 100
        @test audio.sample_rate == 44100
        @test audio.channels == 1
        @test size(audio.samples) == (100, 1)
        @test is_mono(audio)
        @test audio.samples[:, 1] == samples
    end

    @testset "valid stereo from Matrix" begin
        samples = rand(200, 2)
        audio = AudioBuffer(samples, 48000)
        @test num_samples(audio) == 200
        @test audio.sample_rate == 48000
        @test audio.channels == 2
        @test !is_mono(audio)
        @test size(audio.samples) == (200, 2)
    end

    @testset "valid construction with explicit channels" begin
        samples = rand(100, 3)
        audio = AudioBuffer(samples, 44100, 3, AudioMeta())
        @test audio.channels == 3
    end

    @testset "duration calculation" begin
        audio = AudioBuffer(rand(44100), 44100)
        @test duration_sec(audio) ≈ 1.0
    end

    @testset "get_channel" begin
        audio = AudioBuffer(rand(100, 2), 44100)
        ch1 = get_channel(audio, 1)
        ch2 = get_channel(audio, 2)
        @test length(ch1) == 100
        @test length(ch2) == 100
        @test ch1 == audio.samples[:, 1]
        @test ch2 == audio.samples[:, 2]
    end

    @testset "get_channel out of range" begin
        audio = AudioBuffer(rand(100), 44100)
        @test_throws ArgumentError get_channel(audio, 2)
    end

    # ---- 验证 ----
    @testset "reject zero sample_rate" begin
        @test_throws ArgumentError AudioBuffer(rand(100), 0)
    end

    @testset "reject negative sample_rate" begin
        @test_throws ArgumentError AudioBuffer(rand(100), -44100)
    end

    @testset "reject channel mismatch" begin
        @test_throws ArgumentError AudioBuffer(rand(100, 2), 44100, 3, AudioMeta())
    end

    @testset "reject zero channels" begin
        @test_throws ArgumentError AudioBuffer(rand(100, 1), 44100, 0, AudioMeta())
    end

    @testset "reject empty samples" begin
        @test_throws ArgumentError AudioBuffer(zeros(0, 1), 44100, 1, AudioMeta())
    end
end

# ============================================================
# RepairRegion
# ============================================================
@testset "RepairRegion" begin
    @testset "valid construction" begin
        r = RepairRegion(
            start_sample = 1000,
            end_sample = 2000,
            center_sample = 1500,
            start_sec = 0.5,
            end_sec = 1.0,
            center_sec = 0.75,
            score = 0.8,
            label = "seam",
        )
        @test r.start_sample == 1000
        @test r.end_sample == 2000
        @test r.center_sample == 1500
        @test r.score == 0.8
        @test r.label == "seam"
    end

    @testset "default values" begin
        r = RepairRegion(
            start_sample = 0,
            end_sample = 100,
            center_sample = 50,
            start_sec = 0.0,
            end_sec = 0.1,
            center_sec = 0.05,
        )
        @test r.score == 0.0
        @test r.label == "seam"
    end

    @testset "width helpers" begin
        r = RepairRegion(
            start_sample = 100, end_sample = 200, center_sample = 150,
            start_sec = 0.01, end_sec = 0.02, center_sec = 0.015,
        )
        @test region_width_samples(r) == 100
    end

    @testset "reject negative start" begin
        @test_throws ArgumentError RepairRegion(
            -1, 100, 50, -0.1, 0.1, 0.0, 0.5, "seam",
        )
    end

    @testset "reject end <= start" begin
        @test_throws ArgumentError RepairRegion(
            100, 50, 75, 0.1, 0.05, 0.075, 0.5, "seam",
        )
    end

    @testset "reject invalid score" begin
        @test_throws ArgumentError RepairRegion(
            0, 100, 50, 0.0, 0.1, 0.05, 1.5, "seam",
        )
        @test_throws ArgumentError RepairRegion(
            0, 100, 50, 0.0, 0.1, 0.05, -0.1, "seam",
        )
    end
end

# ============================================================
# AlgorithmResult
# ============================================================
@testset "AlgorithmResult" begin
    @testset "valid construction" begin
        audio = AudioBuffer(rand(100), 44100)
        regions = RepairRegion[]
        report = Dict("algorithm_id" => "test_algo")

        result = AlgorithmResult(audio=audio, regions=regions, report=report)
        @test result.audio === audio
        @test isempty(result.regions)
        @test result.report["algorithm_id"] == "test_algo"
    end

    @testset "with regions" begin
        audio = AudioBuffer(rand(500), 44100)
        regions = [
            RepairRegion(
                start_sample=100, end_sample=200, center_sample=150,
                start_sec=0.1, end_sec=0.2, center_sec=0.15, score=0.9,
            ),
        ]
        report = Dict("algorithm_id" => "test_algo", "count" => 1)

        result = AlgorithmResult(audio=audio, regions=regions, report=report)
        @test length(result.regions) == 1
        @test result.regions[1].score == 0.9
    end
end

# ============================================================
# ParamSpec
# ============================================================
@testset "ParamSpec" begin
    @testset "basic float param" begin
        spec = ParamSpec(
            name = :sensitivity,
            type = Float64,
            default = 8.0,
            label = "灵敏度",
            description = "越高越不敏感",
            min = 1.0,
            max = 20.0,
            step = 1.0,
        )
        @test spec.name == :sensitivity
        @test spec.type == Float64
        @test spec.default == 8.0
        @test spec.min == 1.0
        @test spec.max == 20.0
    end

    @testset "choice param" begin
        spec = ParamSpec(
            name = :mode,
            type = String,
            default = "repair",
            label = "模式",
            choices = ["repair", "join"],
        )
        @test spec.choices == ["repair", "join"]
    end
end

# ============================================================
# validate_params
# ============================================================
@testset "validate_params" begin
    specs = [
        ParamSpec(name=:sensitivity, type=Float64, default=8.0, label="Sens", min=1.0, max=20.0),
        ParamSpec(name=:mode, type=String, default="repair", label="Mode", choices=["repair", "join"]),
    ]

    @testset "valid params" begin
        @test validate_params(specs, Dict(:sensitivity => 10.0)) === nothing
        @test validate_params(specs, Dict(:mode => "join")) === nothing
        @test validate_params(specs, Dict(:sensitivity => 10.0, :mode => "repair")) === nothing
    end

    @testset "unknown param" begin
        @test_throws InvalidParamsError validate_params(specs, Dict(:unknown => 5))
    end

    @testset "wrong type" begin
        @test_throws InvalidParamsError validate_params(specs, Dict(:sensitivity => "high"))
    end

    @testset "out of range" begin
        @test_throws InvalidParamsError validate_params(specs, Dict(:sensitivity => 0.0))
        @test_throws InvalidParamsError validate_params(specs, Dict(:sensitivity => 21.0))
    end

    @testset "invalid choice" begin
        @test_throws InvalidParamsError validate_params(specs, Dict(:mode => "invalid"))
    end
end

# ============================================================
# merge_with_defaults
# ============================================================
@testset "merge_with_defaults" begin
    specs = [
        ParamSpec(name=:a, type=Float64, default=1.0, label="A"),
        ParamSpec(name=:b, type=Float64, default=2.0, label="B"),
    ]

    @testset "all defaults" begin
        result = merge_with_defaults(specs, Dict{Symbol, Any}())
        @test result[:a] == 1.0
        @test result[:b] == 2.0
    end

    @testset "partial override" begin
        result = merge_with_defaults(specs, Dict(:a => 10.0))
        @test result[:a] == 10.0
        @test result[:b] == 2.0
    end

    @testset "full override" begin
        result = merge_with_defaults(specs, Dict(:a => 10.0, :b => 20.0))
        @test result[:a] == 10.0
        @test result[:b] == 20.0
    end
end

# ============================================================
# to_dict
# ============================================================
@testset "to_dict" begin
    spec = ParamSpec(
        name = :sensitivity,
        type = Float64,
        default = 8.0,
        label = "灵敏度",
        min = 1.0,
        max = 20.0,
        step = 1.0,
    )
    d = to_dict(spec)
    @test d["name"] == "sensitivity"
    @test d["type"] == "Float64"
    @test d["default"] == 8.0
    @test d["min"] == 1.0
    @test d["max"] == 20.0
    @test d["step"] == 1.0
end

# ============================================================
# Errors
# ============================================================
@testset "Errors" begin
    @testset "SeamFixError hierarchy" begin
        e = UnknownAlgorithmError("test")
        @test e isa SeamFixError
        @test e isa Exception
        @test occursin("test", e.message)

        e2 = InvalidParamsError(:x, "Float64", "String")
        @test e2 isa SeamFixError
        @test occursin("x", e2.message)

        e3 = MediaDecodeError("file.mp3", "not found")
        @test e3 isa SeamFixError
        @test occursin("file.mp3", e3.message)

        e4 = MediaEncodeError("out.wav", "permission denied")
        @test e4 isa SeamFixError

        e5 = AlgorithmExecutionError("algo", "oom")
        @test e5 isa SeamFixError

        e6 = ConfigurationError("ffmpeg_path", "not set")
        @test e6 isa SeamFixError
    end
end

println("✅ All type system tests passed!")