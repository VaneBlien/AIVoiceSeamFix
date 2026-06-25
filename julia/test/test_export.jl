# test_export.jl
# 导出管线测试

using Test
using AIVoiceSeamFix
import AIVoiceSeamFix.ExportPipeline: export_result
import AIVoiceSeamFix.Media.AudioDecode: decode_to_audiobuffer

const EXAMPLES_DIR = joinpath(@__DIR__, "..", "..", "examples")
const OUTPUT_DIR = joinpath(@__DIR__, "..", "..", "output")

function ensure_output_dir()
    if !isdir(OUTPUT_DIR)
        mkdir(OUTPUT_DIR)
    end
end

@testset "ExportPipeline" begin
    ensure_output_dir()

    @testset "export to wav" begin
        input_path = joinpath(EXAMPLES_DIR, "repair_input.wav")
        if !isfile(input_path)
            @warn "Skipping: $input_path not found"
            return
        end

        audio = decode_to_audiobuffer(input_path)
        result = AlgorithmResult(
            audio = audio,
            regions = RepairRegion[],
            report = Dict{String, Any}("test" => true),
        )
        output_path = joinpath(OUTPUT_DIR, "export_test.wav")
        export_result(result, output_path; format=:wav)

        @test isfile(output_path)
        reloaded = decode_to_audiobuffer(output_path)
        @test reloaded.sample_rate == audio.sample_rate
        rm(output_path; force=true)
    end

    @testset "export to mp3" begin
        input_path = joinpath(EXAMPLES_DIR, "repair_input.wav")
        if !isfile(input_path)
            @warn "Skipping: $input_path not found"
            return
        end

        audio = decode_to_audiobuffer(input_path)
        result = AlgorithmResult(
            audio = audio,
            regions = RepairRegion[],
            report = Dict{String, Any}(),
        )
        output_path = joinpath(OUTPUT_DIR, "export_test.mp3")
        export_result(result, output_path; format=:mp3)

        @test isfile(output_path)
        rm(output_path; force=true)
    end

    @testset "export to m4a" begin
        input_path = joinpath(EXAMPLES_DIR, "repair_input.wav")
        if !isfile(input_path)
            @warn "Skipping: $input_path not found"
            return
        end

        audio = decode_to_audiobuffer(input_path)
        result = AlgorithmResult(
            audio = audio,
            regions = RepairRegion[],
            report = Dict{String, Any}(),
        )
        output_path = joinpath(OUTPUT_DIR, "export_test.m4a")
        export_result(result, output_path; format=:m4a)

        @test isfile(output_path)
        rm(output_path; force=true)
    end
end

@testset "Full pipeline: repair + export" begin
    ensure_output_dir()

    input_path = joinpath(EXAMPLES_DIR, "repair_input.wav")
    if !isfile(input_path)
        @warn "Skipping: $input_path not found"
        return
    end

    audio = decode_to_audiobuffer(input_path)
    result = run_repair_algorithm(
        REGISTRY,
        "wavelet_gaussian_repair",
        audio,
        Dict{Symbol, Any}(:sensitivity => 10.0),
        AlgorithmContext(),
    )
    output_path = joinpath(OUTPUT_DIR, "full_pipeline_test.wav")
    export_result(result, output_path; format=:wav)
    @test isfile(output_path)
    rm(output_path; force=true)
end

println("✅ All export tests passed!")