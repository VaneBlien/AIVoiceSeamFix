# ApiServer.jl
# HTTP 服务

module ApiServer

using HTTP
using JSON3
using Logging

import ..ApiPipeline: handle_run, handle_repair, handle_join, handle_algorithms

export start_server

const DEFAULT_HOST = "127.0.0.1"
const DEFAULT_PORT = 8765

function start_server(; host=DEFAULT_HOST, port=DEFAULT_PORT)
    router = HTTP.Router()

    HTTP.register!(router, "OPTIONS", "/*", _cors_handler)
    HTTP.register!(router, "GET", "/api/algorithms", _wrap(handle_algorithms))
    HTTP.register!(router, "POST", "/api/run", _wrap(handle_run))
    HTTP.register!(router, "POST", "/api/repair", _wrap(handle_repair))
    HTTP.register!(router, "POST", "/api/join", _wrap(handle_join))
    HTTP.register!(router, "GET", "/api/status", _wrap(_handle_status))
    HTTP.register!(router, "POST", "/api/shutdown", _wrap(_handle_shutdown))

    println("🎵 AIVoiceSeamFix API server starting on http://$host:$port")
    HTTP.serve(router, host, port)
end

function _cors_handler(req)
    return HTTP.Response(200,
        ["Access-Control-Allow-Origin" => "*",
         "Access-Control-Allow-Methods" => "GET, POST, OPTIONS",
         "Access-Control-Allow-Headers" => "Content-Type"])
end

function _wrap(f)
    return function(req)
        try
            result = f(req)
            body = JSON3.write(result)
            return HTTP.Response(200,
                ["Content-Type" => "application/json",
                 "Access-Control-Allow-Origin" => "*"],
                body = body)
        catch e
            @error "API handler error" exception = (e, catch_backtrace())
            error_json = JSON3.write(Dict(
                "ok" => false,
                "error" => sprint(showerror, e),
            ))
            return HTTP.Response(500,
                ["Content-Type" => "application/json",
                 "Access-Control-Allow-Origin" => "*"],
                body = error_json)
        end
    end
end

function _handle_status(req)
    return Dict{String, Any}(
        "status" => "running",
        "service" => "AIVoiceSeamFix",
    )
end

function _handle_shutdown(req)
    @async begin
        sleep(0.5)
        exit(0)
    end
    return Dict{String, Any}("message" => "shutting down")
end

end