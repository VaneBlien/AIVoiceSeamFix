#!/usr/bin/env python3
"""Phase 4 修复：include 顺序 + 安装依赖"""

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).parent

# 1. 修复 AIVoiceSeamFix.jl 的 include 顺序
main_jl = ROOT / "julia/src/AIVoiceSeamFix.jl"
content = """# AIVoiceSeamFix.jl
# 顶层模块入口

module AIVoiceSeamFix

# ============================================================
# Phase 1 — Core 基础类型
# ============================================================

include("Core/Errors.jl")
using .Errors
export SeamFixError, UnknownAlgorithmError, InvalidParamsError,
       MediaDecodeError, MediaEncodeError, AlgorithmExecutionError,
       ConfigurationError

include("Core/Types.jl")
using .Types
export AudioMeta, AudioBuffer, RepairRegion, AlgorithmResult,
       num_samples, duration_sec, is_mono, get_channel,
       region_width_samples, region_width_sec

include("Core/Params.jl")
using .Params
export ParamSpec, ParamType, validate_params, merge_with_defaults, to_dict

# ============================================================
# Phase 2 — 算法接口
# ============================================================

include("Core/Interface.jl")
using .Interface
export AbstractAudioAlgorithm, AbstractRepairAlgorithm, AbstractJoinAlgorithm,
       AlgorithmContext, algorithm_id, algorithm_name, algorithm_version,
       algorithm_mode, parameter_specs, channel_policy, process,
       algorithm_info

# ============================================================
# Phase 3 — 注册中心 & Runner
# ============================================================

include("Core/Registry.jl")
using .Registry
export AlgorithmRegistry, register_algorithm!, get_algorithm,
       list_algorithms, list_by_mode

include("Core/Runner.jl")
using .Runner
export run_repair_algorithm, run_join_algorithm

# ============================================================
# Phase 4 — 媒体探测（注意 include 顺序）
# ============================================================

include("Media/FFmpegRunner.jl")   # 必须最先：MediaProbe 和 AudioDecode 都依赖它
include("Media/MediaProbe.jl")     # 依赖 FFmpegRunner

# ============================================================
# Phase 5+ — 后续模块
# ============================================================
# TODO: include("Media/AudioDecode.jl")
# TODO: include("Media/AudioEncode.jl")
# TODO: include("Media/VideoMux.jl")
# TODO: include("Media/MediaIO.jl")
# TODO: include("Algorithms/...")
# TODO: include("Pipeline/...")
# TODO: include("Server/...")

end
"""
main_jl.write_text(content, encoding="utf-8")
print(f"✅ 已修复 {main_jl}")

# 2. 修复 MediaProbe.jl — 明确导入 FFmpegRunner
mediaprobe_jl = ROOT / "julia/src/Media/MediaProbe.jl"
mp_content = """# MediaProbe.jl
# 读取媒体文件的元数据：时长、采样率、声道数、编码格式等

module MediaProbe

using JSON3
import ..FFmpegRunner: run_ffprobe, ffprobe_json
using ..Types
using ..Errors

export probe, ProbeResult

Base.@kwdef struct ProbeResult
    file_path::String
    format_name::String = ""
    duration_sec::Float64 = 0.0
    sample_rate::Int = 0
    channels::Int = 0
    codec_name::String = ""
    codec_type::String = ""
    bit_rate::Int = 0
    has_video::Bool = false
    has_audio::Bool = false
    raw::Dict{String, Any} = Dict{String, Any}()
end

function probe(file_path::String)::ProbeResult
    if !isfile(file_path)
        throw(MediaDecodeError(file_path, "file not found"))
    end

    json_str = ffprobe_json(file_path)
    data = JSON3.read(json_str)

    result = ProbeResult(file_path=file_path, raw=data)

    if haskey(data, :format)
        fmt = data.format
        result = ProbeResult(
            file_path = file_path,
            format_name = get(fmt, :format_name, ""),
            duration_sec = parse(Float64, get(fmt, :duration, "0")),
            bit_rate = parse(Int, get(fmt, :bit_rate, "0")),
            raw = data,
        )
    end

    if haskey(data, :streams)
        for stream in data.streams
            codec_type = get(stream, :codec_type, "")
            if codec_type == "audio" && !result.has_audio
                result = ProbeResult(
                    file_path = result.file_path,
                    format_name = result.format_name,
                    duration_sec = result.duration_sec,
                    sample_rate = parse(Int, get(stream, :sample_rate, "0")),
                    channels = parse(Int, get(stream, :channels, "0")),
                    codec_name = get(stream, :codec_name, ""),
                    codec_type = "audio",
                    bit_rate = result.bit_rate,
                    has_video = result.has_video,
                    has_audio = true,
                    raw = result.raw,
                )
            elseif codec_type == "video" && !result.has_video
                result = ProbeResult(
                    file_path = result.file_path,
                    format_name = result.format_name,
                    duration_sec = result.duration_sec,
                    sample_rate = result.sample_rate,
                    channels = result.channels,
                    codec_name = result.codec_name,
                    codec_type = result.codec_type,
                    bit_rate = result.bit_rate,
                    has_video = true,
                    has_audio = result.has_audio,
                    raw = result.raw,
                )
            end
        end
    end

    return result
end

function probe_to_audiometa(result::ProbeResult)::AudioMeta
    return AudioMeta(
        source_path = result.file_path,
        original_format = result.format_name,
        has_video = result.has_video,
        duration_sec = result.duration_sec,
        extra = Dict{String, Any}(
            "codec_name" => result.codec_name,
            "bit_rate" => result.bit_rate,
        ),
    )
end

end
"""
mediaprobe_jl.write_text(mp_content, encoding="utf-8")
print(f"✅ 已修复 {mediaprobe_jl}")

# 3. 安装依赖
print("\n📦 安装 JSON3, WAV ...")
result = subprocess.run(
    ["julia", "--project=julia", "-e", 'import Pkg; Pkg.add("JSON3"); Pkg.add("WAV")'],
    cwd=ROOT, capture_output=True, text=True
)
if result.returncode == 0:
    print("✅ 依赖安装完成")
else:
    print(f"⚠️ 安装输出:\n{result.stdout}\n{result.stderr}")
    # 尝试另一种方式
    subprocess.run(["julia", "--project=julia", "-e", 'import Pkg; Pkg.add("JSON3")'], cwd=ROOT)
    subprocess.run(["julia", "--project=julia", "-e", 'import Pkg; Pkg.add("WAV")'], cwd=ROOT)

# 4. 清理编译缓存
import shutil
compiled = ROOT / "julia/compiled"
if compiled.exists():
    shutil.rmtree(compiled)
    print(f"✅ 已清理 {compiled}")

print("\n" + "="*50)
print("  修复完成，运行测试:")
print("    julia --project=julia julia/test/runtests.jl")
print("="*50)