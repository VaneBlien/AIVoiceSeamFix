# 算法插件开发指南

## 新增算法步骤

1. 在 `Algorithms/Repair/` 或 `Algorithms/Join/` 下创建新文件
2. 定义 struct 继承 `AbstractRepairAlgorithm` 或 `AbstractJoinAlgorithm`
3. 实现以下方法:
   - `algorithm_id` → String
   - `algorithm_name` → String
   - `algorithm_mode` → "repair" | "join"
   - `parameter_specs` → Vector{ParamSpec}
   - `process(algorithm, audio, params, ctx)` → AlgorithmResult
4. 在 `AIVoiceSeamFix.jl` 中 include 新文件
5. 在 `init_algorithms!()` 中注册
6. 添加测试

## 示例

```julia
struct MySpectralRepair <: AbstractRepairAlgorithm end

algorithm_id(::MySpectralRepair) = "my_spectral_repair"
algorithm_name(::MySpectralRepair) = "My Spectral Repair"
algorithm_mode(::MySpectralRepair) = "repair"

function parameter_specs(::MySpectralRepair)
    return [ParamSpec(name=:strength, type=Float64, default=0.5, ...)]
end

function process(alg::MySpectralRepair, audio, params, ctx)
    # 算法逻辑
    return AlgorithmResult(audio=processed_audio, ...)
end
```
