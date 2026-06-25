# test_audio_encode.jl

using Test
using AIVoiceSeamFix.Types
using AIVoiceSeamFix.Errors
import AIVoiceSeamFix.Media.AudioDecode: decode_to_audiobuffer
import AIVoiceSeamFix.Media.AudioEncode: encode_from_audiobuffer

const OUTPUT_DIR = joinpath(@__DIR__, "..", "..", "output")
const EXAMPLES_DIR = joinpath(@__DIR__, "..", "..", "examples")

function ensure_output_dir()
    if !isdir(OUTPUT_DIR)
        mkdir(OUTPUT_DIR)
    end
end

@testset "AudioEncode" begin
    ensure_output_dir()

    @testset "encode wav roundtrip" begin
        input_path = joinpath(EXAMPLES_DIR, "repair_input.wav")
        if !isfile(input_path)
            @warn "Skipping: $input_path not found"
            return
        end
        original = decode_to_audiobuffer(input_path)
        output_path = joinpath(OUTPUT_DIR, "test_output.wav")
        encode_from_audiobuffer(original, output_path; format=:wav)
        @test isfile(output_path)
        decoded = decode_to_audiobuffer(output_path)
        @test decoded.sample_rate == original.sample_rate
        @test decoded.channels == original.channels
        @test num_samples(decoded) == num_samples(original)
        rm(output_path; force=true)
    end

    @testset "encode mp3" begin
        input_path = joinpath(EXAMPLES_DIR, "repair_input.wav")
        if !isfile(input_path)
            @warn "Skipping: $input_path not found"
            return
        end
        original = decode_to_audiobuffer(input_path)
        output_path = joinpath(OUTPUT_DIR, "test_output.mp3")
        encode_from_audiobuffer(original, output_path; format=:mp3)
        @test isfile(output_path)
        decoded = decode_to_audiobuffer(output_path)
        @test decoded.sample_rate == original.sample_rate
        @test contains(decoded.meta.original_format, "mp3")
        rm(output_path; force=true)
    end

    @testset "encode m4a" begin
        input_path = joinpath(EXAMPLES_DIR, "repair_input.wav")
        if !isfile(input_path)
            @warn "Skipping: $input_path not found"
            return
        end
        original = decode_to_audiobuffer(input_path)
        output_path = joinpath(OUTPUT_DIR, "test_output.m4a")
        encode_from_audiobuffer(original, output_path; format=:m4a)
        @test isfile(output_path)
        rm(output_path; force=true)
    end
end

println("✅ All audio encode tests passed!")