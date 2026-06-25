# EqualPowerCrossfadeJoin.jl
# 默认 join 算法：等功率交叉淡化拼接

module EqualPowerCrossfadeJoin

import ...AIVoiceSeamFix
import ...AIVoiceSeamFix: AudioBuffer, AlgorithmResult, RepairRegion, ParamSpec,
                          AbstractJoinAlgorithm, AlgorithmContext, duration_sec
import ...AIVoiceSeamFix: algorithm_id, algorithm_name, algorithm_version,
                          algorithm_mode, parameter_specs, process,
                          merge_with_defaults, validate_params

export EqualPowerCrossfadeJoinAlgorithm

"""
    EqualPowerCrossfadeJoinAlgorithm <: AbstractJoinAlgorithm

默认拼接算法：使用等功率交叉淡化曲线在相邻段之间平滑过渡。
"""
struct EqualPowerCrossfadeJoinAlgorithm <: AbstractJoinAlgorithm end

algorithm_id(::EqualPowerCrossfadeJoinAlgorithm) = "equal_power_crossfade_join"
algorithm_name(::EqualPowerCrossfadeJoinAlgorithm) = "Equal-Power Crossfade Join"
algorithm_version(::EqualPowerCrossfadeJoinAlgorithm) = v"0.1.0"
algorithm_mode(::EqualPowerCrossfadeJoinAlgorithm) = "join"

function parameter_specs(::EqualPowerCrossfadeJoinAlgorithm)
    return [
        ParamSpec(
            name = :fade_ms,
            type = Float64,
            default = 25.0,
            label = "Crossfade 时长 (ms)",
            description = "相邻段之间的交叉淡化时长",
            min = 5.0,
            max = 120.0,
            step = 5.0,
        ),
    ]
end

"""
    process(algorithm::EqualPowerCrossfadeJoinAlgorithm, audios::Vector{AudioBuffer},
            params::Dict{Symbol, Any}, ctx::AlgorithmContext) -> AlgorithmResult

执行等功率交叉淡化拼接。
"""
function process(
    algorithm::EqualPowerCrossfadeJoinAlgorithm,
    audios::Vector{AudioBuffer},
    params::Dict{Symbol, Any},
    ctx::AlgorithmContext,
)::AlgorithmResult
    specs = parameter_specs(algorithm)
    merged = merge_with_defaults(specs, params)
    validate_params(specs, merged)
    fade_ms = merged[:fade_ms]

    if isempty(audios)
        throw(ArgumentError("audios must not be empty"))
    end

    # 统一采样率
    fs = audios[1].sample_rate
    for a in audios
        if a.sample_rate != fs
            throw(ArgumentError("all segments must have the same sample rate"))
        end
    end

    fade_samples = Int(round(fade_ms / 1000 * fs))
    segments = [a.samples[:, 1] for a in audios]

    # 计算总长度
    total_len = sum(length(s) for s in segments) - fade_samples * (length(segments) - 1)
    joined = zeros(Float64, total_len)

    # 等功率交叉淡化曲线: fade_out(t) = cos(π*t/2), fade_in(t) = sin(π*t/2)
    fade_out(t) = cos(π * t / 2)
    fade_in(t) = sin(π * t / 2)

    # 第一段直接拷贝
    offset = 0
    copy_len = length(segments[1])
    joined[1:copy_len] = segments[1]
    offset = copy_len - fade_samples

    # 后续段交叉淡化
    for i in 2:length(segments)
        seg = segments[i]
        overlap = fade_samples

        # 交叉淡化区
        for j in 1:overlap
            idx_out = offset + j
            w_out = fade_out(j / overlap)
            w_in = fade_in(j / overlap)
            joined[idx_out] = w_out * joined[idx_out] + w_in * seg[j]
        end

        # 剩余部分直接拷贝
        remaining = length(seg) - overlap
        if remaining > 0
            joined[offset+overlap+1 : offset+overlap+remaining] = seg[overlap+1:end]
        end

        offset = offset + length(seg) - overlap
    end

    out_audio = AudioBuffer(joined, fs; meta=audios[1].meta)

    return AlgorithmResult(
        audio = out_audio,
        regions = RepairRegion[],
        report = Dict{String, Any}(
            "algorithm_id" => algorithm_id(algorithm),
            "algorithm_name" => algorithm_name(algorithm),
            "segments" => length(audios),
            "fade_ms" => fade_ms,
            "output_duration_sec" => duration_sec(out_audio),
        ),
    )
end

end