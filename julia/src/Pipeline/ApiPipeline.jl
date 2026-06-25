# ApiPipeline.jl
# HTTP 请求 → Runner → JSON 响应

module ApiPipeline

using JSON3

using ..Types: AudioBuffer, RepairRegion, duration_sec
using ..Interface: AlgorithmContext, algorithm_info
using ..Registry: list_algorithms
using ..Runner: run_repair_algorithm, run_join_algorithm
using ..MediaIO: load_audio, save_audio

export handle_algorithms, handle_run, handle_repair, handle_join

# 在 AIVoiceSeamFix.ApiPipeline 子模块内，不要直接写 AIVoiceSeamFix.REGISTRY。
# 子模块作用域里不一定有名为 AIVoiceSeamFix 的绑定。
# 这里从父模块 AIVoiceSeamFix 中取 REGISTRY，避免 UndefVarError。
function _get_registry()
    parent = parentmodule(@__MODULE__)
    if !isdefined(parent, :REGISTRY)
        error("REGISTRY is not defined in parent module. Define and export REGISTRY in AIVoiceSeamFix.jl after algorithm modules are included.")
    end
    return getfield(parent, :REGISTRY)
end

function _params_to_symbol_dict(params_raw)::Dict{Symbol, Any}
    return Dict{Symbol, Any}(Symbol(String(k)) => v for (k, v) in pairs(params_raw))
end

function _get_body(req)
    return JSON3.read(String(req.body))
end

function handle_algorithms(req)
    reg = _get_registry()
    algs = list_algorithms(reg)

    alg_dicts = Vector{Dict{String, Any}}()
    for a in algs
        push!(alg_dicts, algorithm_info(a))
    end

    return Dict{String, Any}(
        "ok" => true,
        "algorithms" => alg_dicts,
    )
end

function handle_run(req)
    body = _get_body(req)

    mode = String(get(body, :mode, "repair"))
    algo_id = String(get(
        body,
        :algorithm_id,
        mode == "repair" ? "wavelet_gaussian_repair" : "equal_power_crossfade_join",
    ))

    output_path = String(get(body, :output_path, ""))
    output_format = Symbol(String(get(body, :output_format, "wav")))
    params_raw = get(body, :params, Dict{String, Any}())
    params = _params_to_symbol_dict(params_raw)

    ctx = AlgorithmContext()

    if mode == "repair"
        input_path = String(get(body, :input_path, ""))
        return _handle_repair_internal(algo_id, input_path, output_path, output_format, params, ctx)
    elseif mode == "join"
        input_paths_raw = get(body, :input_paths, String[])
        input_paths = String.(collect(input_paths_raw))
        return _handle_join_internal(algo_id, input_paths, output_path, output_format, params, ctx)
    else
        return Dict{String, Any}("ok" => false, "error" => "unknown mode: $mode")
    end
end

function handle_repair(req)
    body = _get_body(req)

    algo_id = String(get(body, :algorithm_id, "wavelet_gaussian_repair"))
    input_path = String(body.input_path)
    output_path = String(get(body, :output_path, input_path * "_fixed.wav"))
    output_format = Symbol(String(get(body, :output_format, "wav")))

    params_raw = get(body, :params, Dict{String, Any}())
    params = _params_to_symbol_dict(params_raw)

    ctx = AlgorithmContext()
    return _handle_repair_internal(algo_id, input_path, output_path, output_format, params, ctx)
end

function handle_join(req)
    body = _get_body(req)

    algo_id = String(get(body, :algorithm_id, "equal_power_crossfade_join"))
    input_paths = String.(collect(body.input_paths))
    output_path = String(get(body, :output_path, "joined.wav"))
    output_format = Symbol(String(get(body, :output_format, "wav")))

    params_raw = get(body, :params, Dict{String, Any}())
    params = _params_to_symbol_dict(params_raw)

    ctx = AlgorithmContext()
    return _handle_join_internal(algo_id, input_paths, output_path, output_format, params, ctx)
end

function _handle_repair_internal(algo_id, input_path, output_path, format, params, ctx)
    try
        if isempty(input_path)
            return Dict{String, Any}("ok" => false, "error" => "input_path is required")
        end
        if isempty(output_path)
            output_path = input_path * "_fixed.wav"
        end

        audio = load_audio(input_path)
        reg = _get_registry()
        result = run_repair_algorithm(reg, algo_id, audio, params, ctx)
        save_audio(result.audio, output_path; format = format)

        return Dict{String, Any}(
            "ok" => true,
            "algorithm_id" => result.report["algorithm_id"],
            "detected_regions" => get(result.report, "detected_regions", 0),
            "output_path" => output_path,
        )
    catch e
        return Dict{String, Any}("ok" => false, "error" => sprint(showerror, e))
    end
end

function _handle_join_internal(algo_id, input_paths, output_path, format, params, ctx)
    try
        if isempty(input_paths)
            return Dict{String, Any}("ok" => false, "error" => "input_paths is required")
        end
        if isempty(output_path)
            output_path = "joined.wav"
        end

        audios = [load_audio(p) for p in input_paths]
        reg = _get_registry()
        result = run_join_algorithm(reg, algo_id, audios, params, ctx)
        save_audio(result.audio, output_path; format = format)

        return Dict{String, Any}(
            "ok" => true,
            "algorithm_id" => result.report["algorithm_id"],
            "segments" => get(result.report, "segments", 0),
            "output_path" => output_path,
        )
    catch e
        return Dict{String, Any}("ok" => false, "error" => sprint(showerror, e))
    end
end

end
