# FFmpegRunner.jl
# 封装 ffmpeg / ffprobe 命令行调用

module FFmpegRunner

using ..Errors

export run_ffprobe, run_ffmpeg, ffprobe_json

"""
    run_ffprobe(args::Vector{String}; input_path::String="") -> String

运行 ffprobe 并返回 stdout 字符串。
失败时抛出 MediaDecodeError。
"""
function run_ffprobe(args::Vector{String}; input_path::String="")::String
    cmd = `ffprobe -v quiet $args`
    try
        result = read(cmd, String)
        return result
    catch e
        if e isa ProcessFailedException
            path_info = isempty(input_path) ? "" : " for '$input_path'"
            throw(MediaDecodeError(
                isempty(input_path) ? "ffprobe" : input_path,
                "ffprobe failed$path_info"
            ))
        else
            rethrow()
        end
    end
end

"""
    run_ffprobe(args...; input_path::String="") -> String

便捷调用：run_ffprobe("-i", "file.wav")
每个参数作为独立字符串传入。
"""
function run_ffprobe(args...; input_path::String="")::String
    return run_ffprobe(collect(String, args); input_path=input_path)
end

"""
    ffprobe_json(input_path::String) -> String

以 JSON 格式获取媒体文件信息。
"""
function ffprobe_json(input_path::String)::String
    # 展开路径中的 .. 和 .
    abs_path = abspath(input_path)
    return run_ffprobe(
        "-print_format", "json",
        "-show_format",
        "-show_streams",
        abs_path;
        input_path=abs_path,
    )
end

"""
    run_ffmpeg(args::Vector{String}; error_type::Symbol=:decode) -> Bool

运行 ffmpeg 命令。成功返回 true，失败抛出对应错误。
"""
function run_ffmpeg(args::Vector{String}; error_type::Symbol=:decode)::Bool
    cmd = `ffmpeg -v error -y $args`
    try
        run(cmd)
        return true
    catch e
        if e isa ProcessFailedException
            if error_type == :encode
                throw(MediaEncodeError("ffmpeg", "ffmpeg failed"))
            else
                throw(MediaDecodeError("ffmpeg", "ffmpeg failed"))
            end
        else
            rethrow()
        end
    end
end

"""
    run_ffmpeg(args...; error_type::Symbol=:decode) -> Bool

便捷调用：run_ffmpeg("-i", "in.wav", "out.mp3")
"""
function run_ffmpeg(args...; error_type::Symbol=:decode)::Bool
    return run_ffmpeg(collect(String, args); error_type=error_type)
end

end  # module FFmpegRunner