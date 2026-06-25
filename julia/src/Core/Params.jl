# Params.jl
# 参数描述接口
# 每个算法通过 parameter_specs() 声明参数
# GUI 可通过 /api/algorithms 动态生成参数面板

module Params

using ..Errors

export ParamSpec, ParamType, validate_params, merge_with_defaults, to_dict

# ============================================================
# ParamType — 参数支持的类型
# ============================================================

@enum ParamType begin
    PARAM_FLOAT
    PARAM_INT
    PARAM_BOOL
    PARAM_STRING
    PARAM_CHOICE
end

# ============================================================
# ParamSpec — 参数描述
# ============================================================

Base.@kwdef struct ParamSpec
    name::Symbol
    type::DataType
    default::Any
    label::String
    description::String = ""
    min::Union{Float64, Int, Nothing} = nothing
    max::Union{Float64, Int, Nothing} = nothing
    step::Union{Float64, Int, Nothing} = nothing
    choices::Union{Vector{String}, Nothing} = nothing
end

# ============================================================
# validate_params — 参数验证
# ============================================================

"""
    validate_params(specs::Vector{ParamSpec}, user_params::Dict) -> Nothing

验证用户传入的参数是否符合 ParamSpec 的定义。
失败时抛出 InvalidParamsError。
"""
function validate_params(specs::Vector{ParamSpec}, user_params::Dict)
    spec_map = Dict(spec.name => spec for spec in specs)

    for (name, value) in user_params
        spec = get(spec_map, name, nothing)

        if isnothing(spec)
            throw(InvalidParamsError(
                name,
                "one of [$(join(map(s -> string(s.name), specs), ", "))]",
                "unknown parameter '$name'",
            ))
        end

        if !isa(value, spec.type)
            throw(InvalidParamsError(
                name,
                "$(spec.type)",
                "$(typeof(value))",
            ))
        end

        if spec.type <: Number
            if !isnothing(spec.min) && value < spec.min
                throw(InvalidParamsError(
                    name,
                    ">= $(spec.min)",
                    "$value",
                ))
            end
            if !isnothing(spec.max) && value > spec.max
                throw(InvalidParamsError(
                    name,
                    "<= $(spec.max)",
                    "$value",
                ))
            end
        end

        if !isnothing(spec.choices)
            if !(value in spec.choices)
                throw(InvalidParamsError(
                    name,
                    "one of $(spec.choices)",
                    "\"$value\"",
                ))
            end
        end
    end

    return nothing
end

# ============================================================
# merge_with_defaults
# ============================================================

"""
    merge_with_defaults(specs::Vector{ParamSpec}, user_params::Dict) -> Dict{Symbol, Any}

先用默认值填充，再用用户参数覆盖。
"""
function merge_with_defaults(specs::Vector{ParamSpec}, user_params::Dict)
    merged = Dict{Symbol, Any}(spec.name => spec.default for spec in specs)
    for (k, v) in user_params
        merged[k] = v
    end
    return merged
end

# ============================================================
# to_dict
# ============================================================

"""
    to_dict(spec::ParamSpec) -> Dict

将 ParamSpec 转为可 JSON 序列化的 Dict。
"""
function to_dict(spec::ParamSpec)
    d = Dict{String, Any}(
        "name" => string(spec.name),
        "type" => string(spec.type),
        "default" => spec.default,
        "label" => spec.label,
        "description" => spec.description,
    )
    if !isnothing(spec.min)
        d["min"] = spec.min
    end
    if !isnothing(spec.max)
        d["max"] = spec.max
    end
    if !isnothing(spec.step)
        d["step"] = spec.step
    end
    if !isnothing(spec.choices)
        d["choices"] = spec.choices
    end
    return d
end

end  # module Params