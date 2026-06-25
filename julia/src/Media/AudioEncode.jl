# AudioEncode.jl
# AudioBuffer → wav/mp3/m4a 文件

module AudioEncode

using WAV
import ..FFmpegRunner: run_ffmpeg
using ..Types
using ..Errors

export encode_from_audiobuffer

"""
    encode_from_audiobuffer(audio::AudioBuffer, output_path::String; format::Symbol=:wav)

将 AudioBuffer 编码为音频文件。
- :wav → 直接 WAV.jl 写入
- :mp3 → 临时 WAV → FFmpeg 编码
- :m4a → 临时 WAV → FFmpeg 编码
"""
function encode_from_audiobuffer(audio::AudioBuffer, output_path::String; format::Symbol=:wav)
    if format == :wav
        _encode_wav(audio, output_path)
    elseif format == :mp3
        _encode_compressed(audio, output_path, "libmp3lame", "mp3")
    elseif format == :m4a
        _encode_compressed(audio, output_path, "aac", "ipod")
    else
        throw(MediaEncodeError(output_path, "unsupported format: $format"))
    end
end

function _encode_wav(audio::AudioBuffer, output_path::String)
    try
        WAV.wavwrite(audio.samples, output_path; Fs=audio.sample_rate)
    catch e
        throw(MediaEncodeError(output_path, "WAV write failed: $e"))
    end
end

function _encode_compressed(audio::AudioBuffer, output_path::String, codec::String, format_name::String)
    td = mktempdir()
    temp_wav = joinpath(td, "encode_temp.wav")

    try
        _encode_wav(audio, temp_wav)
        if format_name == "ipod"
            run_ffmpeg("-i", temp_wav, "-c:a", codec, "-b:a", "192k", output_path; error_type=:encode)
        else
            run_ffmpeg("-i", temp_wav, "-c:a", codec, output_path; error_type=:encode)
        end
    catch e
        if e isa MediaEncodeError
            rethrow()
        end
        throw(MediaEncodeError(output_path, "encode failed: $e"))
    finally
        if isfile(temp_wav)
            rm(temp_wav; force=true)
        end
        rm(td; force=true, recursive=true)
    end
end

end