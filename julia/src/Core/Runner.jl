# Runner.jl
# 统一运行入口
# API 层不直接调用具体算法，而是通过 Runner

module Runner

using ..Types
using ..Interface
using ..Registry
using ..Errors

export run_repair_algorithm,
       run_join_algorithm

"""
    run_repair_algorithm(registry::AlgorithmRegistry, algorithm_id_value::String,
                         audio::AudioBuffer, params::Dict{Symbol, Any},
                         ctx::AlgorithmContext) -> AlgorithmResult

根据 algorithm_id 查找 repair 算法并运行。
"""
function run_repair_algorithm(
    registry::AlgorithmRegistry,
    algorithm_id_value::String,
    audio::AudioBuffer,
    params::Dict{Symbol, Any},
    ctx::AlgorithmContext,
)::AlgorithmResult
    algorithm = get_algorithm(registry, algorithm_id_value)

    if !(algorithm isa AbstractRepairAlgorithm)
        throw(ErrorException(
            "Algorithm '$algorithm_id_value' is not a repair algorithm (mode: $(algorithm_mode(algorithm)))"
        ))
    end

    return process(algorithm, audio, params, ctx)
end

"""
    run_join_algorithm(registry::AlgorithmRegistry, algorithm_id_value::String,
                       audios::Vector{AudioBuffer}, params::Dict{Symbol, Any},
                       ctx::AlgorithmContext) -> AlgorithmResult

根据 algorithm_id 查找 join 算法并运行。
"""
function run_join_algorithm(
    registry::AlgorithmRegistry,
    algorithm_id_value::String,
    audios::Vector{AudioBuffer},
    params::Dict{Symbol, Any},
    ctx::AlgorithmContext,
)::AlgorithmResult
    algorithm = get_algorithm(registry, algorithm_id_value)

    if !(algorithm isa AbstractJoinAlgorithm)
        throw(ErrorException(
            "Algorithm '$algorithm_id_value' is not a join algorithm (mode: $(algorithm_mode(algorithm)))"
        ))
    end

    return process(algorithm, audios, params, ctx)
end

end  # module Runner