# Types.jl
# 核心数据类型：所有算法和模块统一使用这些结构体
# 这是项目最底层、最不可变的部分

module Types

using ..Errors

export AudioMeta, AudioBuffer, RepairRegion, AlgorithmResult,
       num_samples, duration_sec, is_mono, get_channel,
       region_width_samples, region_width_sec

# ============================================================
# AudioMeta
# ============================================================

struct AudioMeta
    source_path::Union{String, Nothing}
    original_format::Union{String, Nothing}
    has_video::Bool
    duration_sec::Float64
    extra::Dict{String, Any}
end

function AudioMeta(;
    source_path::Union{String, Nothing}=nothing,
    original_format::Union{String, Nothing}=nothing,
    has_video::Bool=false,
    duration_sec::Real=0.0,
    extra::Dict{String, Any}=Dict{String, Any}(),
)
    if duration_sec < 0
        throw(ArgumentError("duration_sec must be >= 0, got $duration_sec"))
    end

    return AudioMeta(
        source_path,
        original_format,
        has_video,
        Float64(duration_sec),
        extra,
    )
end

# ============================================================
# AudioBuffer
# ============================================================

struct AudioBuffer
    samples::Matrix{Float64}
    sample_rate::Int
    channels::Int
    meta::AudioMeta

    # 内部构造函数：只有在 struct 内部才能使用 new(...)
    function AudioBuffer(
        samples::Matrix{Float64},
        sample_rate::Int,
        channels::Int,
        meta::AudioMeta,
    )
        if sample_rate <= 0
            throw(ArgumentError("sample_rate must be positive, got $sample_rate"))
        end
        if channels < 1
            throw(ArgumentError("channels must be >= 1, got $channels"))
        end
        if isempty(samples)
            throw(ArgumentError("samples matrix must not be empty"))
        end
        if size(samples, 2) != channels
            throw(ArgumentError(
                "samples has $(size(samples, 2)) columns but channels=$channels"
            ))
        end

        return new(samples, sample_rate, channels, meta)
    end
end

# 便捷构造函数：从 Vector，统一转成 samples × channels 的 Matrix
function AudioBuffer(
    samples::AbstractVector{<:Real},
    sample_rate::Int;
    meta::AudioMeta=AudioMeta(),
)
    return AudioBuffer(reshape(Float64.(samples), :, 1), sample_rate, 1, meta)
end

# 便捷构造函数：从 Matrix，自动推导 channels
function AudioBuffer(
    samples::AbstractMatrix{<:Real},
    sample_rate::Int;
    meta::AudioMeta=AudioMeta(),
)
    matrix = Matrix{Float64}(samples)
    return AudioBuffer(matrix, sample_rate, size(matrix, 2), meta)
end

# 便捷构造函数：从 Matrix，显式指定 channels
function AudioBuffer(
    samples::AbstractMatrix{<:Real},
    sample_rate::Int,
    channels::Int;
    meta::AudioMeta=AudioMeta(),
)
    return AudioBuffer(Matrix{Float64}(samples), sample_rate, channels, meta)
end

# ---- 实用方法 ----

num_samples(audio::AudioBuffer)::Int = size(audio.samples, 1)

function duration_sec(audio::AudioBuffer)::Float64
    return num_samples(audio) / audio.sample_rate
end

is_mono(audio::AudioBuffer)::Bool = audio.channels == 1

function get_channel(audio::AudioBuffer, ch::Int)::Vector{Float64}
    if ch < 1 || ch > audio.channels
        throw(ArgumentError("channel $ch out of range [1, $(audio.channels)]"))
    end
    return audio.samples[:, ch]
end

# ============================================================
# RepairRegion
# ============================================================

struct RepairRegion
    start_sample::Int
    end_sample::Int
    center_sample::Int
    start_sec::Float64
    end_sec::Float64
    center_sec::Float64
    score::Float64
    label::String

    # 内部构造函数：负责验证并调用 new(...)
    function RepairRegion(
        start_sample::Int,
        end_sample::Int,
        center_sample::Int,
        start_sec::Float64,
        end_sec::Float64,
        center_sec::Float64,
        score::Float64=0.0,
        label::String="seam",
    )
        if start_sample < 0
            throw(ArgumentError("start_sample must be >= 0"))
        end
        if end_sample <= start_sample
            throw(ArgumentError("end_sample must be > start_sample"))
        end
        if center_sample < start_sample || center_sample > end_sample
            throw(ArgumentError(
                "center_sample must be between start_sample and end_sample"
            ))
        end
        if start_sec < 0 || end_sec < 0 || center_sec < 0
            throw(ArgumentError("region times must be >= 0"))
        end
        if end_sec <= start_sec
            throw(ArgumentError("end_sec must be > start_sec"))
        end
        if center_sec < start_sec || center_sec > end_sec
            throw(ArgumentError("center_sec must be between start_sec and end_sec"))
        end
        if score < 0.0 || score > 1.0
            throw(ArgumentError("score must be in [0.0, 1.0]"))
        end

        return new(
            start_sample,
            end_sample,
            center_sample,
            start_sec,
            end_sec,
            center_sec,
            score,
            label,
        )
    end
end

# keyword constructor：支持 RepairRegion(start_sample=..., ...)
function RepairRegion(;
    start_sample::Int,
    end_sample::Int,
    center_sample::Int,
    start_sec::Real,
    end_sec::Real,
    center_sec::Real,
    score::Real=0.0,
    label::String="seam",
)
    return RepairRegion(
        start_sample,
        end_sample,
        center_sample,
        Float64(start_sec),
        Float64(end_sec),
        Float64(center_sec),
        Float64(score),
        label,
    )
end

region_width_samples(region::RepairRegion)::Int =
    region.end_sample - region.start_sample

region_width_sec(region::RepairRegion)::Float64 =
    region.end_sec - region.start_sec

# ============================================================
# AlgorithmResult
# ============================================================

struct AlgorithmResult
    audio::AudioBuffer
    regions::Vector{RepairRegion}
    report::Dict{String, Any}
end

function AlgorithmResult(
    audio::AudioBuffer;
    regions::Vector{RepairRegion}=RepairRegion[],
    report::AbstractDict{String, <:Any}=Dict{String, Any}(),
)
    return AlgorithmResult(audio, regions, Dict{String, Any}(report))
end

function AlgorithmResult(;
    audio::AudioBuffer,
    regions::Vector{RepairRegion}=RepairRegion[],
    report::AbstractDict{String, <:Any}=Dict{String, Any}(),
)
    return AlgorithmResult(audio, regions, Dict{String, Any}(report))
end

end  # module Types