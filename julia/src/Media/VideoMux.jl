# VideoMux.jl
# 视频音轨替换：保留原始视频轨，替换音频轨

module VideoMux

import ..FFmpegRunner: run_ffmpeg
using ..Errors

export mux_video_with_audio

"""
    mux_video_with_audio(video_path::String, audio_path::String, output_path::String)

将修复后的音频替换回原视频。
- 视频轨：copy（不重新编码）
- 音频轨：用 audio_path 替换
"""
function mux_video_with_audio(video_path::String, audio_path::String, output_path::String)
    if !isfile(video_path)
        throw(MediaDecodeError(video_path, "video file not found"))
    end
    if !isfile(audio_path)
        throw(MediaDecodeError(audio_path, "audio file not found"))
    end

    try
        run_ffmpeg(
            "-i", video_path,
            "-i", audio_path,
            "-c:v", "copy",
            "-c:a", "aac",
            "-map", "0:v:0",
            "-map", "1:a:0",
            "-shortest",
            output_path;
            error_type = :encode,
        )
    catch e
        if e isa MediaEncodeError
            rethrow()
        end
        throw(MediaEncodeError(output_path, "video mux failed: $e"))
    end
end

end