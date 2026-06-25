# MediaProbe.jl
# 读取媒体文件的元数据：时长、采样率、声道数、编码格式等

module MediaProbe

using JSON3
import ..FFmpegRunner: ffprobe_json
using ..Types
using ..Errors

export probe, ProbeResult, probe_to_audiometa

# ============================================================
# 安全的 JSON 值转换
# ============================================================

_json_string(x, default::String="")::String = x === nothing ? default : string(x)

function _json_int(x, default::Int=0)::Int
    x === nothing && return default
    x isa Integer && return Int(x)
    x isa AbstractFloat && return Int(round(x))
    parsed = tryparse(Int, strip(string(x)))
    return parsed === nothing ? default : parsed
end

function _json_float(x, default::Float64=0.0)::Float64
    x === nothing && return default
    x isa Real && return Float64(x)
    parsed = tryparse(Float64, strip(string(x)))
    return parsed === nothing ? default : parsed
end

# ============================================================
# ProbeResult
# ============================================================

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
    raw::Any = nothing
end

# ============================================================
# probe
# ============================================================

function probe(file_path::String)::ProbeResult
    if !isfile(file_path)
        throw(MediaDecodeError(file_path, "file not found"))
    end

    json_str = ffprobe_json(file_path)
    data = JSON3.read(json_str)

    result = ProbeResult(file_path=file_path, raw=data)

    # 解析 format 信息
    if haskey(data, :format)
        fmt = data.format
        result = ProbeResult(
            file_path = file_path,
            format_name = _json_string(get(fmt, :format_name, nothing)),
            duration_sec = _json_float(get(fmt, :duration, nothing)),
            bit_rate = _json_int(get(fmt, :bit_rate, nothing)),
            raw = data,
        )
    end

    # 解析 stream 信息
    if haskey(data, :streams)
        for stream in data.streams
            codec_type = _json_string(get(stream, :codec_type, nothing))

            if codec_type == "audio" && !result.has_audio
                result = ProbeResult(
                    file_path = result.file_path,
                    format_name = result.format_name,
                    duration_sec = result.duration_sec,
                    sample_rate = _json_int(get(stream, :sample_rate, nothing)),
                    channels = _json_int(get(stream, :channels, nothing)),
                    codec_name = _json_string(get(stream, :codec_name, nothing)),
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

# ============================================================
# probe_to_audiometa
# ============================================================

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