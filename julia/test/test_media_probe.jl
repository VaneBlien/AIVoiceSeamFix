# test_media_probe.jl
# 媒体探测测试

using Test
using AIVoiceSeamFix.Errors

import AIVoiceSeamFix.FFmpegRunner: run_ffprobe, ffprobe_json
import AIVoiceSeamFix.MediaProbe: probe, probe_to_audiometa, ProbeResult

const EXAMPLES_DIR = joinpath(@__DIR__, "..", "..", "examples")

# ============================================================
# FFmpegRunner
# ============================================================

@testset "FFmpegRunner" begin
    @testset "ffprobe_json valid file" begin
        wav_path = joinpath(EXAMPLES_DIR, "repair_input.wav")
        if isfile(wav_path)
            json_str = ffprobe_json(wav_path)
            @test contains(json_str, "streams") || contains(json_str, "format")
        else
            @warn "Test file not found: $wav_path (skipping ffprobe test)"
        end
    end

    @testset "ffprobe_json nonexistent file" begin
        @test_throws MediaDecodeError ffprobe_json("/nonexistent/file.wav")
    end

    @testset "run_ffprobe" begin
        wav_path = joinpath(EXAMPLES_DIR, "repair_input.wav")
        if isfile(wav_path)
            # 用 -show_streams 让 ffprobe 输出可解析的信息
            output = run_ffprobe(
                "-show_streams",
                wav_path;
                input_path = wav_path,
            )
            @test contains(output, "[STREAM]")
            @test contains(output, "codec_type")
        else
            @warn "Test file not found: $wav_path (skipping run_ffprobe test)"
        end
    end
end

# ============================================================
# MediaProbe
# ============================================================

@testset "MediaProbe" begin
    @testset "probe wav file" begin
        wav_path = joinpath(EXAMPLES_DIR, "repair_input.wav")
        if isfile(wav_path)
            result = probe(wav_path)
            @test result.file_path == wav_path
            @test result.has_audio == true
            @test result.sample_rate > 0
            @test result.channels >= 1
            @test result.duration_sec > 0.0
        else
            @warn "Test file not found: $wav_path (skipping probe test)"
        end
    end

    @testset "probe nonexistent file" begin
        @test_throws MediaDecodeError probe("/nonexistent/file.mp3")
    end

    @testset "probe_to_audiometa" begin
        wav_path = joinpath(EXAMPLES_DIR, "repair_input.wav")
        if isfile(wav_path)
            result = probe(wav_path)
            meta = probe_to_audiometa(result)
            @test meta.source_path == wav_path
            @test meta.duration_sec == result.duration_sec
            @test meta.has_video == result.has_video
            @test haskey(meta.extra, "codec_name")
        else
            @warn "Test file not found: $wav_path (skipping probe_to_audiometa test)"
        end
    end

    @testset "probe mp3 file" begin
        mp3_path = joinpath(EXAMPLES_DIR, "repair_input.mp3")
        if isfile(mp3_path)
            result = probe(mp3_path)
            @test result.has_audio == true
            @test length(result.format_name) > 0
        else
            @warn "Test file not found: $mp3_path (skipping mp3 probe test)"
        end
    end

    @testset "probe mp4 file" begin
        mp4_path = joinpath(EXAMPLES_DIR, "repair_input.mp4")
        if isfile(mp4_path)
            result = probe(mp4_path)
            @test result.has_audio == true
            @test result.has_video == true
        else
            @warn "Test file not found: $mp4_path (skipping mp4 probe test)"
        end
    end
end

println("✅ All media probe tests passed!")