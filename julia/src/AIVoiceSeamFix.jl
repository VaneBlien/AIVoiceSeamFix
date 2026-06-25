# AIVoiceSeamFix.jl
# 顶层模块入口

module AIVoiceSeamFix

# ============================================================
# Phase 1 — Core 基础类型
# ============================================================

include("Core/Errors.jl")
using .Errors
export SeamFixError, UnknownAlgorithmError, InvalidParamsError,
       MediaDecodeError, MediaEncodeError, AlgorithmExecutionError,
       ConfigurationError

include("Core/Types.jl")
using .Types
export AudioMeta, AudioBuffer, RepairRegion, AlgorithmResult,
       num_samples, duration_sec, is_mono, get_channel,
       region_width_samples, region_width_sec

include("Core/Params.jl")
using .Params
export ParamSpec, ParamType, validate_params, merge_with_defaults, to_dict

# ============================================================
# Phase 2 — 算法接口
# ============================================================

include("Core/Interface.jl")
using .Interface
export AbstractAudioAlgorithm, AbstractRepairAlgorithm, AbstractJoinAlgorithm,
       AlgorithmContext, algorithm_id, algorithm_name, algorithm_version,
       algorithm_mode, parameter_specs, channel_policy, process,
       algorithm_info

# ============================================================
# Phase 3 — 注册中心 & Runner
# ============================================================

include("Core/Registry.jl")
using .Registry
export AlgorithmRegistry, register_algorithm!, get_algorithm,
       list_algorithms, list_by_mode

include("Core/Runner.jl")
using .Runner
export run_repair_algorithm, run_join_algorithm

# ============================================================
# Phase 4 — 媒体探测
# ============================================================

include("Media/FFmpegRunner.jl")
include("Media/MediaProbe.jl")

# ============================================================
# Phase 5 — 媒体编解码 & 视频混流
# ============================================================

include("Media/AudioDecode.jl")
include("Media/AudioEncode.jl")
include("Media/VideoMux.jl")
include("Media/MediaIO.jl")

# ============================================================
# Media namespace facade
# ============================================================

module Media
import ..FFmpegRunner
import ..MediaProbe
import ..AudioDecode
import ..AudioEncode
import ..VideoMux
import ..MediaIO
end

# ============================================================
# Phase 6 — 算法组件：小波检测
# ============================================================

include("Algorithms/Common/Kernels.jl")
include("Algorithms/Repair/WaveletDetector.jl")

# ============================================================
# Phase 7 — 区域构建 + 高斯平滑
# ============================================================

include("Algorithms/Repair/RegionBuilder.jl")
include("Algorithms/Repair/GaussianSmoother.jl")

# ============================================================
# Phase 8 — 修复算法组装
# ============================================================

include("Algorithms/Repair/WaveletGaussianRepair.jl")

# ============================================================
# Phase 9 — Join 算法 + Pipeline + Server
# ============================================================

include("Algorithms/Join/EqualPowerCrossfadeJoin.jl")
include("Pipeline/ApiPipeline.jl")
include("Server/ApiServer.jl")

# ============================================================
# Phase 10 — 导出管线
# ============================================================

include("Pipeline/ExportPipeline.jl")

# ============================================================
# Algorithms namespace facade
# ============================================================

module Algorithms
module Repair
import ...WaveletDetector
import ...RegionBuilder
import ...GaussianSmoother
import ...WaveletGaussianRepair
end
module Common
import ...Kernels
end
module Join
import ...EqualPowerCrossfadeJoin
end
end

# ============================================================
# Pipeline namespace facade
# ============================================================

module Pipeline
import ..ExportPipeline
import ..ApiPipeline
end

# ============================================================
# Server namespace facade
# ============================================================

module Server
import ..ApiServer
end

# ============================================================
# 全局 Registry
# ============================================================

export REGISTRY

const REGISTRY = AlgorithmRegistry()

function __init__()
    empty!(REGISTRY.algorithms)
    register_algorithm!(REGISTRY, WaveletGaussianRepair.WaveletGaussianRepairAlgorithm())
    register_algorithm!(REGISTRY, EqualPowerCrossfadeJoin.EqualPowerCrossfadeJoinAlgorithm())
end

end