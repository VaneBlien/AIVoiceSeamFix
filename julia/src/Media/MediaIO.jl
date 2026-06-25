# MediaIO.jl
# 统一媒体入口：load/save AudioBuffer

module MediaIO

using WAV
using ..Types
using ..Errors
using ..AudioDecode: decode_to_audiobuffer
import ..FFmpegRunner: run_ffmpeg

export load_audio, save_audio, supported_input_formats, supported_output_formats

# ============================================================
# 支持的格式
# ============================================================

function supported_input_formats()
    return ["wav", "mp3", "m4a", "aac", "flac", "ogg", "mp4", "mov"]
end

function supported_output_formats()
    return ["wav", "mp3", "m4a"]
end

# ============================================================
# 内部工具
# ============================================================

function _extension(path::String)::String
    ext = lowercase(splitext(path)[2])
    return startswith(ext, ".") ? ext[2:end] : ext
end

function _ensure_parent_dir(path::String)
    dir = dirname(path)
    if !isempty(dir) && !isdir(dir)
        mkpath(dir)
    end
end

function _write_temp_wav(audio::AudioBuffer, temp_wav::String)
    _ensure_parent_dir(temp_wav)
    WAV.wavwrite(audio.samples, temp_wav; Fs = audio.sample_rate)
    return temp_wav
end

# ============================================================
# 输入
# ============================================================

"""
    load_audio(input_path::String) -> AudioBuffer

从文件加载音频，返回 AudioBuffer。
WAV/MP3/M4A/MP4 等格式统一交给 AudioDecode。
"""
function load_audio(input_path::String)::AudioBuffer
    if !isfile(input_path)
        throw(MediaDecodeError(input_path, "file not found"))
    end

    return decode_to_audiobuffer(input_path)
end

# ============================================================
# 输出
# ============================================================

"""
    save_audio(audio::AudioBuffer, output_path::String; format::Symbol=:wav)

将 AudioBuffer 保存为音频文件。
- :wav：直接 WAV.wavwrite
- :mp3：临时 WAV → FFmpeg/libmp3lame
- :m4a：临时 WAV → FFmpeg/aac
"""
function save_audio(audio::AudioBuffer, output_path::String; format::Symbol = :wav)
    _ensure_parent_dir(output_path)

    fmt = format
    if fmt == :auto
        ext = _extension(output_path)
        fmt = ext == "mp3" ? :mp3 :
              ext == "m4a" ? :m4a :
              ext == "wav" ? :wav :
              throw(MediaEncodeError(output_path, "unsupported output extension: .$ext"))
    end

    if fmt == :wav
        WAV.wavwrite(audio.samples, output_path; Fs = audio.sample_rate)
        return output_path
    elseif fmt == :mp3 || fmt == :m4a
        temp_dir = mktempdir()
        temp_wav = joinpath(temp_dir, "encode_source.wav")

        try
            _write_temp_wav(audio, temp_wav)

            if fmt == :mp3
                run_ffmpeg(
                    "-y",
                    "-i", temp_wav,
                    "-vn",
                    "-codec:a", "libmp3lame",
                    "-q:a", "2",
                    output_path,
                )
            else
                run_ffmpeg(
                    "-y",
                    "-i", temp_wav,
                    "-vn",
                    "-codec:a", "aac",
                    "-b:a", "192k",
                    output_path,
                )
            end

            return output_path
        catch e
            if e isa MediaEncodeError
                rethrow()
            end
            throw(MediaEncodeError(output_path, "encode failed: $(sprint(showerror, e))"))
        finally
            isfile(temp_wav) && rm(temp_wav; force = true)
            isdir(temp_dir) && rm(temp_dir; force = true, recursive = true)
        end
    else
        throw(MediaEncodeError(output_path, "unsupported output format: $fmt"))
    end
end

end  # module MediaIO
