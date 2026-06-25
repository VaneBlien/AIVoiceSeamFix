# WaveletDetector.jl
# 小波变换/多尺度突变检测音频断裂点

module WaveletDetector

using Statistics
using Wavelets

export detect_breaks_wavelet, detect_breaks_wavevel, WaveletDetectorResult

"""
    WaveletDetectorResult

小波检测的原始输出。
"""
Base.@kwdef struct WaveletDetectorResult
    break_samples::Vector{Int}
    detail_signal::Vector{Float64}
    threshold::Float64
    wavelet::String
    level::Int
    sensitivity::Float64
end

# ============================================================
# 小波基构造
# ============================================================

function _make_wavelet(name::String)
    if name == "db4"
        return wavelet(WT.db4)
    elseif name == "db2"
        return wavelet(WT.db2)
    elseif name == "haar"
        return wavelet(WT.haar)
    elseif name == "sym4"
        return wavelet(SYM.sym4)
    else
        throw(ArgumentError("unsupported wavelet: $name. Supported: db2, db4, haar, sym4"))
    end
end

function _next_pow2_at_least(n::Int, min_pow::Int)::Int
    target = max(n, 2^min_pow)
    return 2 ^ ceil(Int, log2(target))
end

function _pad_for_dwt(samples::Vector{Float64}, level::Int)::Vector{Float64}
    n = length(samples)
    N = _next_pow2_at_least(n, max(level, 1))

    if N == n
        return samples
    end

    padded = Vector{Float64}(undef, N)
    padded[1:n] .= samples

    # 用边界值填充，避免零填充在尾部制造额外突变
    padded[n+1:end] .= samples[end]
    return padded
end

function _mad(x::AbstractVector{<:Real})::Float64
    isempty(x) && return 0.0
    med = median(x)
    return median(abs.(x .- med))
end

function _local_rms_contrast(samples::Vector{Float64}, sample_rate::Int)::Vector{Float64}
    n = length(samples)
    w = max(8, sample_rate ÷ 200)  # 约 5ms
    score = zeros(Float64, n)

    if n <= 2w + 2
        return score
    end

    energy = samples .^ 2
    cs = cumsum(vcat(0.0, energy))

    @inbounds for i in (w + 1):(n - w)
        left_energy = (cs[i] - cs[i - w]) / w
        right_energy = (cs[i + w] - cs[i]) / w
        score[i] = abs(sqrt(max(left_energy, 0.0)) - sqrt(max(right_energy, 0.0)))
    end

    return score
end

function _second_difference_score(samples::Vector{Float64})::Vector{Float64}
    n = length(samples)
    score = zeros(Float64, n)

    if n < 3
        return score
    end

    @inbounds for i in 2:(n - 1)
        score[i] = abs(samples[i + 1] - 2samples[i] + samples[i - 1])
    end

    return score
end

function _wavelet_score(samples::Vector{Float64}, wavelet_name::String, level::Int)::Vector{Float64}
    n = length(samples)
    wt = _make_wavelet(wavelet_name)
    padded = _pad_for_dwt(samples, level)

    # Wavelets.dwt 对长度因子有要求；前面已经 pad 到 2 的幂。
    coeffs = dwt(padded, wt, level)

    # 对 flat coefficient vector 取高频半区作为 detail proxy。
    # 这里不直接返回 coeffs，因为它的长度是 padded 后长度。
    detail = abs.(coeffs[(length(coeffs) ÷ 2 + 1):end])

    # 简单线性映射回原始长度，避免依赖 DSP.resample。
    score = zeros(Float64, n)
    m = length(detail)

    if m == 0
        return score
    end

    @inbounds for i in 1:n
        j = clamp(round(Int, (i - 1) * (m - 1) / max(n - 1, 1)) + 1, 1, m)
        score[i] = detail[j]
    end

    return score
end

function _normalize_max(x::Vector{Float64})::Vector{Float64}
    mx = maximum(x)
    if !isfinite(mx) || mx <= eps(Float64)
        return zeros(Float64, length(x))
    end
    return x ./ mx
end

# ============================================================
# 主检测函数
# ============================================================

"""
    detect_breaks_wavelet(samples::Vector{Float64}, sample_rate::Int;
                          wavelet::String="db4", level::Int=3,
                          sensitivity::Float64=8.0) -> Vector{Int}

用多尺度突变分数检测音频中的断裂点，返回断裂点的样本索引列表。

参数:
- samples: 单声道音频样本
- sample_rate: 采样率
- wavelet: 小波基名称，默认 "db4"
- level: 分解层数，默认 3
- sensitivity: 检测灵敏度，越高越不敏感
"""
function detect_breaks_wavelet(
    samples::Vector{Float64},
    sample_rate::Int;
    wavelet::String = "db4",
    level::Int = 3,
    sensitivity::Float64 = 8.0,
)
    if sample_rate <= 0
        throw(ArgumentError("sample_rate must be positive"))
    end

    n = length(samples)

    # 至少 100ms，太短没有足够上下文
    if n < sample_rate ÷ 10
        return Int[]
    end

    # 组合三个分数：
    # 1. 小波高频 proxy
    # 2. 局部 RMS 对比，适合检测拼接前后响度变化
    # 3. 二阶差分，适合检测尖锐突变
    wave_score = _normalize_max(_wavelet_score(samples, wavelet, level))
    rms_score = _normalize_max(_local_rms_contrast(samples, sample_rate))
    diff_score = _normalize_max(_second_difference_score(samples))

    detail = 0.45 .* wave_score .+ 0.45 .* rms_score .+ 0.10 .* diff_score

    med = median(detail)
    mad = _mad(detail)

    # MAD 很小时，说明几乎没有局部突变；直接返回空，避免纯净正弦被误判。
    if mad <= 1e-8
        return Int[]
    end

    threshold = med + sensitivity * mad * 1.4826

    min_distance = max(1, sample_rate ÷ 100)  # 约 10ms
    edge_guard = max(min_distance, sample_rate ÷ 200)

    breaks = Int[]
    i = max(2, edge_guard)

    while i <= n - max(1, edge_guard)
        if detail[i] > threshold &&
           detail[i] >= detail[i - 1] &&
           detail[i] >= detail[i + 1]

            if isempty(breaks) || (i - breaks[end] >= min_distance)
                push!(breaks, i)
                i += min_distance
                continue
            end
        end

        i += 1
    end

    return breaks
end

# 兼容别名（测试中历史拼写为 wavevel）
detect_breaks_wavevel(args...; kwargs...) = detect_breaks_wavelet(args...; kwargs...)

end
