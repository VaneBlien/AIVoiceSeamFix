# AudioDecode.jl
# 任意音频/视频格式 → AudioBuffer
# 内部：非 WAV 格式先通过 FFmpeg 转为临时 WAV，再用 WAV.jl 读取

module AudioDecode

using WAV
import ..FFmpegRunner: run_ffmpeg
import ..MediaProbe: probe
using ..Types
using ..Errors

export decode_to_audiobuffer

# ============================================================
# Internal helpers
# ============================================================

function _extension(path::String)::String
    ext = lowercase(splitext(path)[2])
    return startswith(ext, ".") ? ext[2:end] : ext
end

function _as_float64_matrix(samples)::Matrix{Float64}
    if samples isa AbstractVector
        return reshape(Float64.(samples), :, 1)
    elseif samples isa AbstractMatrix
        return Matrix{Float64}(samples)
    else
        throw(ArgumentError("unsupported sample container: $(typeof(samples))"))
    end
end

function _read_wav_as_buffer(
    wav_path::String;
    source_path::String = wav_path,
    original_format::String = "wav",
    has_video::Bool = false,
    duration_sec::Union{Nothing, Float64} = nothing,
    extra::Dict{String, Any} = Dict{String, Any}(),
)::AudioBuffer
    samples_raw, sample_rate_raw = WAV.wavread(wav_path)

    samples = _as_float64_matrix(samples_raw)
    sample_rate = Int(round(sample_rate_raw))
    channels = size(samples, 2)

    dur = duration_sec === nothing ? size(samples, 1) / sample_rate : duration_sec

    meta = AudioMeta(
        source_path = source_path,
        original_format = original_format,
        has_video = has_video,
        duration_sec = dur,
        extra = extra,
    )

    return AudioBuffer(samples, sample_rate, channels, meta)
end

"""
    decode_to_audiobuffer(input_path::String; temp_dir::String="") -> AudioBuffer

将任意支持的音频/视频文件解码为 AudioBuffer。
- WAV: 直接读取
- MP3/M4A/AAC/FLAC/OGG: FFmpeg → 临时 WAV → 读取
- MP4/MOV: FFmpeg 提取音轨 → 临时 WAV → 读取
"""
function decode_to_audiobuffer(input_path::String; temp_dir::String="")::AudioBuffer
    if !isfile(input_path)
        throw(MediaDecodeError(input_path, "file not found"))
    end

    ext = _extension(input_path)

    # WAV 直接读。注意 WAV.wavread 的 sample_rate 可能是 Float32，
    # AudioBuffer 内部要求 Int，所以必须归一化。
    if ext == "wav"
        return _read_wav_as_buffer(
            input_path;
            source_path = input_path,
            original_format = "wav",
        )
    end

    # 非 WAV：FFmpeg 解码为临时 WAV。
    # 如果外部传入 temp_dir，则由外部管理目录生命周期；
    # 否则本函数创建并清理临时目录。
    owns_temp_dir = isempty(temp_dir)
    td = owns_temp_dir ? mktempdir() : temp_dir
    isdir(td) || mkpath(td)

    temp_wav = joinpath(td, "decode_temp_$(rand(UInt32)).wav")

    try
        # -y 覆盖临时输出；-vn 忽略视频流；-acodec pcm_s16le 输出普通 WAV。
        run_ffmpeg(
            "-y",
            "-i", input_path,
            "-vn",
            "-acodec", "pcm_s16le",
            temp_wav,
        )

        probe_result = probe(input_path)

        return _read_wav_as_buffer(
            temp_wav;
            source_path = input_path,
            original_format = probe_result.format_name,
            has_video = probe_result.has_video,
            duration_sec = probe_result.duration_sec,
            extra = Dict{String, Any}(
                "codec_name" => probe_result.codec_name,
                "codec_type" => probe_result.codec_type,
                "bit_rate" => probe_result.bit_rate,
                "sample_rate" => probe_result.sample_rate,
                "channels" => probe_result.channels,
            ),
        )
    catch e
        if e isa MediaDecodeError || e isa MediaEncodeError
            rethrow()
        end
        throw(MediaDecodeError(input_path, "decode failed: $(sprint(showerror, e))"))
    finally
        isfile(temp_wav) && rm(temp_wav; force = true)
        owns_temp_dir && isdir(td) && rm(td; force = true, recursive = true)
    end
end

end
