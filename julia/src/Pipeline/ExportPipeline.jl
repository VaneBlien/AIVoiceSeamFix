# ExportPipeline.jl
# AlgorithmResult → 输出文件

module ExportPipeline

import ..AIVoiceSeamFix: AlgorithmResult
import ..Media.MediaIO: save_audio
import ..Media.VideoMux: mux_video_with_audio

export export_result

"""
    export_result(result::AlgorithmResult, output_path::String;
                  format::Symbol=:wav, video_source::Union{String, Nothing}=nothing)

将 AlgorithmResult 导出为文件。

- format: :wav, :mp3, :m4a
- video_source: 如果提供，将音频替换回原视频
"""
function export_result(
    result::AlgorithmResult,
    output_path::String;
    format::Symbol = :wav,
    video_source::Union{String, Nothing} = nothing,
)
    if isnothing(video_source)
        save_audio(result.audio, output_path; format=format)
    else
        # 先导出音频，再混流回视频
        temp_audio = output_path * "_temp_audio.wav"
        try
            save_audio(result.audio, temp_audio; format=:wav)
            mux_video_with_audio(video_source, temp_audio, output_path)
        finally
            if isfile(temp_audio)
                rm(temp_audio; force=true)
            end
        end
    end
end

end