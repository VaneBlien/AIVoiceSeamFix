# WaveletGaussianRepair.jl
# 默认 repair 算法：小波检测 + 高斯卷积平滑

module WaveletGaussianRepair

using ...AIVoiceSeamFix
using ...AIVoiceSeamFix: AudioBuffer, AlgorithmResult, RepairRegion,
                         AlgorithmContext, ParamSpec,
                         AbstractRepairAlgorithm
import ...AIVoiceSeamFix: algorithm_id, algorithm_name, algorithm_version,
                          algorithm_mode, parameter_specs, channel_policy,
                          process, merge_with_defaults, validate_params
import ..WaveletDetector: detect_breaks_wavelet
import ..RegionBuilder: build_regions
import ..GaussianSmoother: smooth_regions

export WaveletGaussianRepairAlgorithm

"""
    WaveletGaussianRepairAlgorithm <: AbstractRepairAlgorithm

默认修复算法：小波变换检测断裂点 → 区域构建 → 高斯卷积局部平滑。
"""
struct WaveletGaussianRepairAlgorithm <: AbstractRepairAlgorithm end

algorithm_id(::WaveletGaussianRepairAlgorithm) = "wavelet_gaussian_repair"
algorithm_name(::WaveletGaussianRepairAlgorithm) = "Wavelet + Gaussian Repair"
algorithm_version(::WaveletGaussianRepairAlgorithm) = v"0.1.0"
algorithm_mode(::WaveletGaussianRepairAlgorithm) = "repair"
channel_policy(::WaveletGaussianRepairAlgorithm) = :mono

function parameter_specs(::WaveletGaussianRepairAlgorithm)
    return [
        ParamSpec(
            name = :sensitivity,
            type = Float64,
            default = 8.0,
            label = "检测灵敏度",
            description = "数值越高，误检越少，但可能漏检",
            min = 2.0,
            max = 20.0,
            step = 1.0,
        ),
        ParamSpec(
            name = :expand_ms,
            type = Float64,
            default = 50.0,
            label = "区域扩展 (ms)",
            description = "断裂点向两侧扩展的时长",
            min = 10.0,
            max = 120.0,
            step = 5.0,
        ),
        ParamSpec(
            name = :merge_ms,
            type = Float64,
            default = 80.0,
            label = "区域合并 (ms)",
            description = "两个区域间距小于此值时合并",
            min = 10.0,
            max = 200.0,
            step = 5.0,
        ),
        ParamSpec(
            name = :window_ms,
            type = Float64,
            default = 60.0,
            label = "平滑窗口 (ms)",
            description = "高斯平滑窗口的半宽度",
            min = 10.0,
            max = 150.0,
            step = 5.0,
        ),
        ParamSpec(
            name = :sigma_ms,
            type = Float64,
            default = 4.0,
            label = "高斯 sigma (ms)",
            description = "高斯核标准差",
            min = 1.0,
            max = 20.0,
            step = 1.0,
        ),
        ParamSpec(
            name = :alpha,
            type = Float64,
            default = 0.45,
            label = "平滑强度",
            description = "0=保持原样，1=完全平滑",
            min = 0.1,
            max = 0.8,
            step = 0.05,
        ),
    ]
end


# ============================================================
# 参数归一化
# ============================================================

function _coerce_param_value(expected_type::Type, value)
    if expected_type === Float64 && value isa Real
        return Float64(value)
    elseif expected_type === Int && value isa Real
        return Int(round(value))
    elseif expected_type === String
        return String(value)
    elseif expected_type === Bool && value isa Bool
        return value
    else
        return value
    end
end

function _coerce_params_for_specs(specs, params::AbstractDict{Symbol, <:Any})::Dict{Symbol, Any}
    out = Dict{Symbol, Any}(params)

    for spec in specs
        if haskey(out, spec.name)
            out[spec.name] = _coerce_param_value(spec.type, out[spec.name])
        end
    end

    return out
end

"""
    process(algorithm::WaveletGaussianRepairAlgorithm, audio::AudioBuffer,
            params::Dict{Symbol, Any}, ctx::AlgorithmContext) -> AlgorithmResult

执行修复流程：
1. 提取第一声道
2. 小波检测断裂点
3. 构建修复区域
4. 高斯卷积平滑
5. 返回 AlgorithmResult
"""
function process(
    algorithm::WaveletGaussianRepairAlgorithm,
    audio::AudioBuffer,
    params::Dict{Symbol, Any},
    ctx::AlgorithmContext,
)::AlgorithmResult
    return _process_wavelet_gaussian_repair(algorithm, audio, params, ctx)
end

function process(
    algorithm::WaveletGaussianRepairAlgorithm,
    audio::AudioBuffer,
    params::AbstractDict{Symbol, <:Any},
    ctx::AlgorithmContext,
)::AlgorithmResult
    return _process_wavelet_gaussian_repair(
        algorithm,
        audio,
        Dict{Symbol, Any}(params),
        ctx,
    )
end

function _process_wavelet_gaussian_repair(
    algorithm::WaveletGaussianRepairAlgorithm,
    audio::AudioBuffer,
    params::Dict{Symbol, Any},
    ctx::AlgorithmContext,
)::AlgorithmResult
    # 合并默认参数。
    # 注意：Dict{Symbol, Float64} 不是 Dict{Symbol, Any} 的子类型，
    # 所以这里先统一转换，保证 GUI/API/测试传入不同 value 类型时都能处理。
    specs = parameter_specs(algorithm)

    # GUI/JSON3 可能把 8.0 这类值解析成 Int64。
    # 参数声明是 Float64 时，这里先把 Real 数值统一转成 Float64，
    # 再交给 validate_params 做范围和类型校验。
    params_any = _coerce_params_for_specs(specs, params)
    merged = merge_with_defaults(specs, params_any)
    merged = _coerce_params_for_specs(specs, merged)
    validate_params(specs, merged)

    sensitivity = merged[:sensitivity]
    expand_ms = merged[:expand_ms]
    merge_ms = merged[:merge_ms]
    window_ms = merged[:window_ms]
    sigma_ms = merged[:sigma_ms]
    alpha = merged[:alpha]

    # 提取第一声道
    y = audio.samples[:, 1]
    fs = audio.sample_rate

    # 步骤 1: 检测
    points = detect_breaks_wavelet(y, fs; sensitivity=sensitivity)

    # 步骤 2: 构建区域
    regions = build_regions(points, length(y), fs;
                            expand_ms=expand_ms, merge_ms=merge_ms)

    # 步骤 3: 平滑
    fixed = smooth_regions(y, regions, fs;
                           window_ms=window_ms, sigma_ms=sigma_ms, alpha=alpha)

    # 步骤 4: 构造输出
    out_samples = reshape(fixed, :, 1)
    out_audio = AudioBuffer(out_samples, fs; meta = audio.meta)

    return AlgorithmResult(
        audio = out_audio,
        regions = regions,
        report = Dict{String, Any}(
            "algorithm_id" => algorithm_id(algorithm),
            "algorithm_name" => algorithm_name(algorithm),
            "detected_points" => length(points),
            "detected_regions" => length(regions),
            "params" => Dict(
                "sensitivity" => sensitivity,
                "expand_ms" => expand_ms,
                "merge_ms" => merge_ms,
                "window_ms" => window_ms,
                "sigma_ms" => sigma_ms,
                "alpha" => alpha,
            ),
        ),
    )
end

end