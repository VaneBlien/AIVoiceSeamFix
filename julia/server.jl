#!/usr/bin/env julia
# server.jl
# AIVoiceSeamFix 服务启动入口
#
# 用法:
#   julia --project=julia julia/server.jl
#   julia --project=julia julia/server.jl --port 9000

push!(LOAD_PATH, joinpath(@__DIR__, "src"))

using AIVoiceSeamFix
import AIVoiceSeamFix.Server.ApiServer: start_server

function main()
    port = 8765

    # 解析命令行参数
    for arg in ARGS
        if startswith(arg, "--port=")
            port = parse(Int, arg[8:end])
        elseif arg == "--help" || arg == "-h"
            println("""
            AIVoiceSeamFix Server

            用法: julia --project=julia julia/server.jl [选项]

            选项:
              --port=N    服务端口 (默认: 8765)
              --help, -h  显示帮助
            """)
            return
        end
    end

    println("="^50)
    println("  AIVoiceSeamFix Server")
    println("  Port: $port")
    println("  Algorithms: repair + join")
    println("="^50)

    start_server(port=port)
end

main()