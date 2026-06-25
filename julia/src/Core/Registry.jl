# Registry.jl
# 算法注册中心
# 所有算法通过 register_algorithm! 注册
# API 层通过 get_algorithm / list_algorithms 查询

module Registry

using ..Interface
using ..Errors

export AlgorithmRegistry,
       register_algorithm!,
       get_algorithm,
       list_algorithms,
       list_by_mode

"""
    AlgorithmRegistry

算法注册中心。持有所有已注册算法的实例。
"""
mutable struct AlgorithmRegistry
    algorithms::Dict{String, AbstractAudioAlgorithm}

    function AlgorithmRegistry()
        return new(Dict{String, AbstractAudioAlgorithm}())
    end
end

"""
    register_algorithm!(registry::AlgorithmRegistry, algorithm::AbstractAudioAlgorithm) -> AlgorithmRegistry

注册一个算法实例。如果 algorithm_id 已存在则抛出错误。
"""
function register_algorithm!(
    registry::AlgorithmRegistry,
    algorithm::AbstractAudioAlgorithm,
)
    id = algorithm_id(algorithm)

    if haskey(registry.algorithms, id)
        error("Algorithm already registered: '$id'")
    end

    registry.algorithms[id] = algorithm
    return registry
end

"""
    get_algorithm(registry::AlgorithmRegistry, id::String) -> AbstractAudioAlgorithm

根据 algorithm_id 获取算法实例。不存在时抛出 UnknownAlgorithmError。
"""
function get_algorithm(registry::AlgorithmRegistry, id::String)
    algorithm = get(registry.algorithms, id, nothing)
    if isnothing(algorithm)
        throw(UnknownAlgorithmError(id))
    end
    return algorithm
end

"""
    list_algorithms(registry::AlgorithmRegistry) -> Vector{AbstractAudioAlgorithm}

返回所有已注册算法的列表。
"""
function list_algorithms(registry::AlgorithmRegistry)
    return collect(values(registry.algorithms))
end

"""
    list_by_mode(registry::AlgorithmRegistry, mode::String) -> Vector{AbstractAudioAlgorithm}

按模式筛选算法（"repair" 或 "join"）。
"""
function list_by_mode(registry::AlgorithmRegistry, mode::String)
    return [alg for alg in values(registry.algorithms) if algorithm_mode(alg) == mode]
end

end  # module Registry