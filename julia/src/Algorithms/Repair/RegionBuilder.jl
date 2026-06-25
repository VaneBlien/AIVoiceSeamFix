# RegionBuilder.jl
# 将检测到的断裂点扩展、合并为 RepairRegion 列表

module RegionBuilder

using ..Types: RepairRegion

export build_regions

"""
    build_regions(points::Vector{Int}, total_samples::Int, sample_rate::Int;
                  expand_ms::Float64=50.0, merge_ms::Float64=80.0) -> Vector{RepairRegion}

将断裂点列表转换为修复区域列表。

参数:
- points: 断裂点样本索引列表
- total_samples: 音频总样本数
- sample_rate: 采样率
- expand_ms: 每个点向两侧扩展的时长 (ms)，默认 50ms → 区域宽度 100ms
- merge_ms: 两个区域间距小于此值则合并 (ms)，默认 80ms

返回:
- RepairRegion 列表，按时间排序，边界已裁切到 [0, total_samples)
"""
function build_regions(
    points::Vector{Int},
    total_samples::Int,
    sample_rate::Int;
    expand_ms::Float64 = 50.0,
    merge_ms::Float64 = 80.0,
)::Vector{RepairRegion}
    if sample_rate <= 0
        throw(ArgumentError("sample_rate must be positive"))
    end
    if total_samples <= 0 || isempty(points)
        return RepairRegion[]
    end

    expand_samples = Int(round(expand_ms / 1000 * sample_rate))
    merge_samples = Int(round(merge_ms / 1000 * sample_rate))

    regions = RepairRegion[]

    for p in sort(points)
        center = clamp(p, 0, total_samples)
        start_s = max(0, center - expand_samples)
        end_s = min(total_samples, center + expand_samples)

        # RepairRegion 要求 end_sample > start_sample
        if end_s <= start_s
            continue
        end

        if isempty(regions)
            push!(regions, _make_region(start_s, end_s, center, sample_rate, 0.5, "seam"))
            continue
        end

        last_r = regions[end]

        if start_s - last_r.end_sample <= merge_samples
            merged_start = last_r.start_sample
            merged_end = max(last_r.end_sample, end_s)
            merged_center = clamp((merged_start + merged_end) ÷ 2, merged_start, merged_end)
            regions[end] = _make_region(
                merged_start,
                merged_end,
                merged_center,
                sample_rate,
                max(last_r.score, 0.5),
                last_r.label,
            )
        else
            push!(regions, _make_region(start_s, end_s, center, sample_rate, 0.5, "seam"))
        end
    end

    return regions
end

function _make_region(
    start_s::Int,
    end_s::Int,
    center_s::Int,
    sr::Int,
    score::Float64,
    label::String,
)::RepairRegion
    return RepairRegion(
        start_sample = start_s,
        end_sample = end_s,
        center_sample = center_s,
        start_sec = start_s / sr,
        end_sec = end_s / sr,
        center_sec = center_s / sr,
        score = score,
        label = label,
    )
end

end
