#!/usr/bin/env julia
# runtests.jl — 测试入口

push!(LOAD_PATH, joinpath(@__DIR__, "..", "src"))

using Test
using AIVoiceSeamFix

const TEST_DIR = @__DIR__

function run_all_tests()
    # Phase 1 — 类型系统
    include_test("test_types.jl")

    # Phase 2 — 算法接口
    include_test("test_interface.jl")

    # Phase 3 — 注册中心 & Runner
    include_test("test_registry.jl")
    include_test("test_runner.jl")

    # Phase 4 — 媒体探测
    include_test("test_media_probe.jl")

    # Phase 5 — 媒体编解码
    include_test("test_audio_decode.jl")
    include_test("test_audio_encode.jl")

    # Phase 6 — 小波检测
    include_test("test_detector.jl")

    # Phase 7 — 区域构建 + 高斯平滑
    include_test("test_region_builder.jl")
    include_test("test_smoother.jl")

    # Phase 8 — 修复算法组装
    include_test("test_pipeline.jl")

    # Phase 9 — Join 算法
    include_test("test_crossfade.jl")

    # Phase 10 — 导出管线
    include_test("test_export.jl")

    # Phase 11+ — 后续阶段
    # include_test("test_api.jl")
    # include_test("test_video_mux.jl")
end

function include_test(filename::String)
    filepath = joinpath(TEST_DIR, filename)
    if isfile(filepath)
        @info "Running $filename ..."
        include(filepath)
    else
        @warn "Test file not found: $filepath (skipping)"
    end
end

@testset "AIVoiceSeamFix" begin
    run_all_tests()
end

println("\n" * "="^60)
println("  AIVoiceSeamFix — Test Suite Complete")
println("="^60)