# Interface.jl
# 抽象算法接口
# 所有算法必须继承 AbstractAudioAlgorithm 并实现对应方法
# 新算法只需实现这些接口，不关心 MediaIO / HTTP / GUI

module Interface

using ..Types
using ..Params

export AbstractAudioAlgorithm,
       AbstractRepairAlgorithm,
       AbstractJoinAlgorithm,
       AlgorithmContext,
       algorithm_id,
       algorithm_name,
       algorithm_version,
       algorithm_mode,
       parameter_specs,
       channel_policy,
       process,
       algorithm_info

# ============================================================
# 抽象类型层次
# ============================================================

"""
    AbstractAudioAlgorithm

所有算法的抽象基类。
"""
abstract type AbstractAudioAlgorithm end

"""
    AbstractRepairAlgorithm <: AbstractAudioAlgorithm

修复算法基类。接收单个 AudioBuffer，检测并修复断裂点。
"""
abstract type AbstractRepairAlgorithm <: AbstractAudioAlgorithm end

"""
    AbstractJoinAlgorithm <: AbstractAudioAlgorithm

拼接算法基类。接收多个 AudioBuffer，通过交叉淡化拼接。
"""
abstract type AbstractJoinAlgorithm <: AbstractAudioAlgorithm end

# ============================================================
# AlgorithmContext
# ============================================================

"""
    AlgorithmContext

算法执行上下文，携带临时目录、日志目录、取消标志等。
"""
Base.@kwdef mutable struct AlgorithmContext
    temp_dir::String = ""
    log_dir::String = ""
    request_id::String = ""
    cancel_requested::Bool = false
end

# ============================================================
# 接口函数（默认实现抛 NotImplementedError）
# ============================================================

"""
    algorithm_id(::AbstractAudioAlgorithm) -> String

返回算法的唯一标识符，如 "wavelet_gaussian_repair"。
"""
function algorithm_id(::AbstractAudioAlgorithm)::String
    error("algorithm_id not implemented for $(typeof(alg))")
end

"""
    algorithm_name(::AbstractAudioAlgorithm) -> String

返回算法的可读名称，如 "Wavelet + Gaussian Repair"。
"""
function algorithm_name(::AbstractAudioAlgorithm)::String
    error("algorithm_name not implemented for $(typeof(alg))")
end

"""
    algorithm_version(::AbstractAudioAlgorithm) -> VersionNumber

返回算法版本号，默认 v"0.1.0"。
"""
algorithm_version(::AbstractAudioAlgorithm) = v"0.1.0"

"""
    algorithm_mode(::AbstractAudioAlgorithm) -> String

返回算法模式："repair" 或 "join"。
"""
function algorithm_mode(::AbstractAudioAlgorithm)::String
    error("algorithm_mode not implemented for $(typeof(alg))")
end

"""
    parameter_specs(::AbstractAudioAlgorithm) -> Vector{ParamSpec}

返回算法的可调参数列表，供 GUI 动态生成参数面板。
默认返回空列表（无参数）。
"""
parameter_specs(::AbstractAudioAlgorithm) = ParamSpec[]

"""
    channel_policy(::AbstractAudioAlgorithm) -> Symbol

返回算法的声道处理策略：
- :mono       — 降混为单声道处理
- :passthrough — 保持原始声道数
默认 :mono。
"""
channel_policy(::AbstractAudioAlgorithm) = :mono

# ============================================================
# process — 核心算法入口
# ============================================================

"""
    process(algorithm::AbstractRepairAlgorithm, audio::AudioBuffer,
            params::Dict{Symbol, Any}, ctx::AlgorithmContext) -> AlgorithmResult

修复算法入口。接收单个音频，返回修复后的 AlgorithmResult。
"""
function process(
    algorithm::AbstractRepairAlgorithm,
    audio::AudioBuffer,
    params::Dict{Symbol, Any},
    ctx::AlgorithmContext,
)::AlgorithmResult
    error("repair process not implemented for $(algorithm_id(algorithm))")
end

"""
    process(algorithm::AbstractJoinAlgorithm, audios::Vector{AudioBuffer},
            params::Dict{Symbol, Any}, ctx::AlgorithmContext) -> AlgorithmResult

拼接算法入口。接收多个音频段，返回拼接后的 AlgorithmResult。
"""
function process(
    algorithm::AbstractJoinAlgorithm,
    audios::Vector{AudioBuffer},
    params::Dict{Symbol, Any},
    ctx::AlgorithmContext,
)::AlgorithmResult
    error("join process not implemented for $(algorithm_id(algorithm))")
end

# ============================================================
# 工具：生成算法信息摘要（供 API 使用）
# ============================================================

"""
    algorithm_info(algorithm::AbstractAudioAlgorithm) -> Dict

返回算法的完整描述，供 GET /api/algorithms 序列化。
"""
function algorithm_info(algorithm::AbstractAudioAlgorithm)
    # 先把 ParamSpec 转成 Dict
    param_dicts = Vector{Dict{String, Any}}()
    for spec in parameter_specs(algorithm)
        push!(param_dicts, Params.to_dict(spec))
    end

    return Dict{String, Any}(
        "id" => algorithm_id(algorithm),
        "name" => algorithm_name(algorithm),
        "version" => string(algorithm_version(algorithm)),
        "mode" => algorithm_mode(algorithm),
        "channel_policy" => string(channel_policy(algorithm)),
        "params" => param_dicts,
    )
end

end  # module Interface