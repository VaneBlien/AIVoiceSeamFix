# GaussianSmoother.jl
# 高斯卷积核局部平滑修复

module GaussianSmoother

using ..Types: RepairRegion
using ..Kernels: gaussian_kernel
using DSP: conv

export smooth_regions

"""
    smooth_regions(samples::Vector{Float64}, regions::Vector{RepairRegion},
                   sample_rate::Int; window_ms::Float64=60.0,
                   sigma_ms::Float64=4.0, alpha::Float64=0.45) -> Vector{Float64}

对指定区域进行高斯卷积平滑，返回修复后的波形。
"""
function smooth_regions(
    samples::Vector{Float64},
    regions::Vector{RepairRegion},
    sample_rate::Int;
    window_ms::Float64 = 60.0,
    sigma_ms::Float64 = 4.0,
    alpha::Float64 = 0.45,
)::Vector{Float64}
    if sample_rate <= 0
        throw(ArgumentError("sample_rate must be positive"))
    end
    if sigma_ms <= 0
        throw(ArgumentError("sigma_ms must be positive"))
    end
    if alpha < 0.0 || alpha > 1.0
        throw(ArgumentError("alpha must be in [0, 1]"))
    end
    if isempty(samples) || isempty(regions)
        return copy(samples)
    end

    fixed = copy(samples)

    half_window = max(1, Int(round(window_ms / 1000 * sample_rate)))
    sigma_samples = sigma_ms / 1000 * sample_rate
    radius = max(1, Int(round(3.0 * sigma_samples)))

    kernel = gaussian_kernel(radius, sigma_samples)

    for region in regions
        # RepairRegion 使用 0-based sample 边界；Julia 数组是 1-based。
        proc_start = max(1, region.start_sample - half_window + 1)
        proc_end = min(length(samples), region.end_sample + half_window)
        n = proc_end - proc_start + 1

        if n < 5
            continue
        end

        segment = copy(view(fixed, proc_start:proc_end))

        padded = vcat(
            fill(segment[1], radius),
            segment,
            fill(segment[end], radius),
        )

        smoothed_full = conv(padded, kernel)

        # conv length = length(padded) + length(kernel) - 1
        # padding radius + kernel center radius
        offset = 2 * radius
        smoothed = smoothed_full[offset + 1 : offset + n]

        # 局部混合权重：区域中心更强，边界渐隐，避免产生新断点。
        t = range(-1.0, 1.0, length = n)
        weight = alpha .* exp.(-(t .^ 2) ./ (2 * 0.3^2))

        fixed[proc_start:proc_end] .= weight .* smoothed .+ (1.0 .- weight) .* segment
    end

    return fixed
end

end
