# Kernels.jl
# 通用卷积核

module Kernels

export gaussian_kernel

"""
    gaussian_kernel(radius_samples::Int, sigma_samples::Float64) -> Vector{Float64}

生成归一化的高斯卷积核。
- radius_samples: 核的半宽度（样本数），核总长度为 2*radius_samples + 1
- sigma_samples: 高斯标准差（样本数）
"""
function gaussian_kernel(radius_samples::Int, sigma_samples::Float64)
    if radius_samples < 0
        throw(ArgumentError("radius_samples must be >= 0, got $radius_samples"))
    end
    if sigma_samples <= 0
        throw(ArgumentError("sigma_samples must be > 0, got $sigma_samples"))
    end

    n = 2 * radius_samples + 1
    kernel = Vector{Float64}(undef, n)

    for i in 1:n
        x = (i - 1 - radius_samples) / sigma_samples
        kernel[i] = exp(-0.5 * x^2)
    end

    # 归一化
    kernel ./= sum(kernel)
    return kernel
end

end