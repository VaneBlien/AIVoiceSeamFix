# test_audio_decode.jl

using Test
using AIVoiceSeamFix.Types
using AIVoiceSeamFix.Errors
import AIVoiceSeamFix.Media.AudioDecode: decode_to_audiobuffer

const EXAMPLES_DIR = joinpath(@__DIR__, "..", "..", "examples")

@testset "AudioDecode" begin
    @testset "decode wav" begin
        path = joinpath(EXAMPLES_DIR, "repair_input.wav")
        if isfile(path)
            audio = decode_to_audiobuffer(path)
            @test audio isa AudioBuffer
            @test audio.sample_rate > 0
            @test audio.channels >= 1
            @test num_samples(audio) > 0
            @test audio.meta.original_format == "wav"
        else
            @warn "Skipping: $path not found"
        end
    end

    @testset "decode mp3" begin
        path = joinpath(EXAMPLES_DIR, "repair_input.mp3")
        if isfile(path)
            audio = decode_to_audiobuffer(path)
            @test audio isa AudioBuffer
            @test audio.sample_rate > 0
            @test contains(audio.meta.original_format, "mp3")
        else
            @warn "Skipping: $path not found"
        end
    end

    @testset "decode mp4" begin
        path = joinpath(EXAMPLES_DIR, "repair_input.mp4")
        if isfile(path)
            audio = decode_to_audiobuffer(path)
            @test audio isa AudioBuffer
            @test audio.sample_rate > 0
            @test audio.meta.has_video == true
        else
            @warn "Skipping: $path not found"
        end
    end

    @testset "decode nonexistent" begin
        @test_throws MediaDecodeError decode_to_audiobuffer("/nonexistent/file.wav")
    end
end

println("✅ All audio decode tests passed!")