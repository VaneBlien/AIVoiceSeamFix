# Errors.jl
# 统一错误类型层次
# 所有自定义异常继承自 SeamFixError，方便上层统一捕获

module Errors

export SeamFixError,
       UnknownAlgorithmError,
       InvalidParamsError,
       MediaDecodeError,
       MediaEncodeError,
       AlgorithmExecutionError,
       ConfigurationError

"""
    SeamFixError <: Exception

AIVoiceSeamFix 所有自定义异常的基类。
"""
abstract type SeamFixError <: Exception end

"""
    UnknownAlgorithmError

请求的 algorithm_id 在 Registry 中不存在。
"""
struct UnknownAlgorithmError <: SeamFixError
    algorithm_id::String
    message::String

    function UnknownAlgorithmError(algorithm_id::String)
        return new(algorithm_id, "Unknown algorithm: '$algorithm_id'")
    end
end

"""
    InvalidParamsError

参数验证失败时抛出。
"""
struct InvalidParamsError <: SeamFixError
    param_name::Symbol
    expected::String
    got::String
    message::String

    function InvalidParamsError(param_name::Symbol, expected::String, got::String)
        msg = "Invalid parameter '$(param_name)': expected $expected, got $got"
        return new(param_name, expected, got, msg)
    end
end

"""
    MediaDecodeError

媒体解码失败（文件不存在、格式不支持、FFmpeg 错误等）。
"""
struct MediaDecodeError <: SeamFixError
    path::String
    reason::String
    message::String

    function MediaDecodeError(path::String, reason::String)
        msg = "Failed to decode media file: '$path' — $reason"
        return new(path, reason, msg)
    end
end

"""
    MediaEncodeError

媒体编码/写入失败。
"""
struct MediaEncodeError <: SeamFixError
    path::String
    reason::String
    message::String

    function MediaEncodeError(path::String, reason::String)
        msg = "Failed to encode media file: '$path' — $reason"
        return new(path, reason, msg)
    end
end

"""
    AlgorithmExecutionError

算法执行过程中发生内部错误。
"""
struct AlgorithmExecutionError <: SeamFixError
    algorithm_id::String
    reason::String
    message::String

    function AlgorithmExecutionError(algorithm_id::String, reason::String)
        msg = "Algorithm '$(algorithm_id)' failed: $reason"
        return new(algorithm_id, reason, msg)
    end
end

"""
    ConfigurationError

配置文件解析或环境变量错误。
"""
struct ConfigurationError <: SeamFixError
    key::String
    reason::String
    message::String

    function ConfigurationError(key::String, reason::String)
        msg = "Configuration error for '$(key)': $reason"
        return new(key, reason, msg)
    end
end

# ---- 重载 Base.showerror 以便友好输出 ----

function Base.showerror(io::IO, e::SeamFixError)
    print(io, e.message)
end

end  # module Errors