```markdown
# AIVoiceSeamFix

AI 生成配音断裂点检测与平滑修复工具。

AI TTS 拼接的音频在片段连接处常有波形不连续（毛刺/爆音），拖进 PR 或 Audition 就能看到明显的断裂。AIVoiceSeamFix 用小波变换自动检测断裂位置，再用高斯卷积核平滑过渡，输出自然流畅的音频。

## 效果

- 修复前：AI 拼接处有明显毛刺，声音发闷
- 修复后：过渡平滑自然，声音清脆

## 架构

```
输入文件 (wav/mp3/m4a/mp4)
       │
       ▼
  MediaIO 解码
       │
       ▼
  AudioBuffer
       │
       ▼
  AlgorithmCore
  (小波检测 → 区域构建 → 高斯平滑)
       │
       ▼
  AlgorithmResult
       │
       ▼
  ExportPipeline 编码输出
```

算法模块只处理 `AudioBuffer → AlgorithmResult`，不关心文件格式、GUI 和 HTTP。新增算法只需实现 `Core/Interface.jl` 中的接口。

## 技术栈

| 层 | 技术 |
|---|------|
| 算法后端 | Julia (Wavelets.jl + DSP.jl) |
| HTTP 服务 | HTTP.jl + JSON3.jl |
| 媒体处理 | FFmpeg / FFprobe |
| 前端 GUI | Python 3 + PyQt6 |
| 测试 | Julia Test 标准库 |

## 快速开始

### 环境要求

- Julia ≥ 1.10
- Python ≥ 3.10
- FFmpeg / FFprobe（在 PATH 中可用）

### 1. 安装 Julia 依赖

```bash
cd julia
julia --project=. -e 'import Pkg; Pkg.instantiate()'
```

### 2. 创建 Python 虚拟环境

```bash
python setup_gui_env.py
```

### 3. 生成测试音频（可选，用于跑测试）

```bash
python create_test_audio.py
```

### 4. 启动后端服务

```bash
julia --project=julia julia/server.jl
```

看到 `🎵 AIVoiceSeamFix API server starting on http://127.0.0.1:8765` 即就绪。

### 5. 启动 GUI

```bash
# Windows
scripts\start_gui.bat

# macOS / Linux
bash scripts/start_gui.sh
```

### 6. 运行测试

```bash
julia --project=julia julia/test/runtests.jl
```

## 项目结构

```
AIVoiceSeamFix/
├── julia/                        # Julia 后端
│   ├── server.jl                 # 服务入口
│   ├── Project.toml
│   └── src/
│       ├── AIVoiceSeamFix.jl     # 顶层模块
│       ├── Core/                  # 核心抽象层
│       │   ├── Types.jl          # AudioBuffer, RepairRegion 等
│       │   ├── Params.jl         # ParamSpec 参数描述
│       │   ├── Interface.jl      # 抽象算法接口
│       │   ├── Registry.jl       # 算法注册中心
│       │   ├── Runner.jl         # 统一运行入口
│       │   └── Errors.jl         # 错误类型
│       ├── Media/                 # 媒体 IO 层
│       │   ├── FFmpegRunner.jl   # FFmpeg/FFprobe 调用
│       │   ├── MediaProbe.jl     # 媒体元数据探测
│       │   ├── AudioDecode.jl    # 解码 → AudioBuffer
│       │   ├── AudioEncode.jl    # AudioBuffer → 文件
│       │   ├── VideoMux.jl       # 视频音轨替换
│       │   └── MediaIO.jl        # 统一入口
│       ├── Algorithms/            # 算法实现
│       │   ├── Common/
│       │   │   └── Kernels.jl    # 高斯核等通用工具
│       │   ├── Repair/
│       │   │   ├── WaveletDetector.jl     # 小波检测
│       │   │   ├── RegionBuilder.jl       # 区域构建
│       │   │   ├── GaussianSmoother.jl    # 高斯平滑
│       │   │   └── WaveletGaussianRepair.jl  # 完整修复算法
│       │   └── Join/
│       │       └── EqualPowerCrossfadeJoin.jl  # 等功率交叉淡化
│       ├── Pipeline/
│       │   ├── ApiPipeline.jl    # HTTP 请求处理
│       │   └── ExportPipeline.jl # 结果导出
│       ├── Server/
│       │   └── ApiServer.jl      # HTTP 服务
│       └── test/                 # 测试
│           └── ...
├── gui/                          # Python GUI
│   ├── main.py
│   ├── requirements.txt
│   └── app/
│       ├── main_window.py
│       ├── services/             # API 客户端、文件管理、播放器
│       ├── workers/              # 后台线程
│       └── widgets/              # 拖拽区、参数面板、结果、日志
├── config/
│   └── default.toml
├── contracts/                    # 接口规范文档
├── docs/                         # 架构、算法、插件开发文档
├── scripts/                      # 启动/关闭脚本
├── examples/                     # 测试音频
└── output/                       # 修复输出
```

## API 端点

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/api/algorithms` | 列出所有算法及参数 |
| POST | `/api/run` | 统一运行接口 |
| POST | `/api/repair` | 修复快捷方式 |
| POST | `/api/join` | 拼接快捷方式 |
| GET | `/api/status` | 服务状态 |
| POST | `/api/shutdown` | 关闭服务 |

### 示例请求

```bash
# 查询算法
curl http://127.0.0.1:8765/api/algorithms

# 修复音频
curl -X POST http://127.0.0.1:8765/api/run \
  -H "Content-Type: application/json" \
  -d '{
    "mode": "repair",
    "algorithm_id": "wavelet_gaussian_repair",
    "input_path": "/path/to/input.wav",
    "output_path": "/path/to/output.wav",
    "params": {"sensitivity": 8.0, "alpha": 0.45}
  }'
```

## 算法参数

### 修复算法 (wavelet_gaussian_repair)

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| sensitivity | Float64 | 8.0 | 检测灵敏度，越高越不敏感 |
| expand_ms | Float64 | 50.0 | 区域扩展宽度 (ms) |
| merge_ms | Float64 | 80.0 | 区域合并距离 (ms) |
| window_ms | Float64 | 60.0 | 平滑窗口半宽 (ms) |
| sigma_ms | Float64 | 4.0 | 高斯核标准差 (ms) |
| alpha | Float64 | 0.45 | 平滑强度 (0-1) |

### 拼接算法 (equal_power_crossfade_join)

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| fade_ms | Float64 | 25.0 | 交叉淡化时长 (ms) |

## 开发新算法

继承 `AbstractRepairAlgorithm` 或 `AbstractJoinAlgorithm`，实现接口方法即可：

```julia
struct MyNewRepair <: AbstractRepairAlgorithm end

algorithm_id(::MyNewRepair) = "my_new_repair"
algorithm_name(::MyNewRepair) = "My New Repair"
algorithm_mode(::MyNewRepair) = "repair"

function parameter_specs(::MyNewRepair)
    return [ParamSpec(name=:strength, type=Float64, default=0.5, ...)]
end

function process(alg::MyNewRepair, audio, params, ctx)
    # 算法逻辑
    return AlgorithmResult(audio=processed_audio, ...)
end
```

然后在 `AIVoiceSeamFix.jl` 的 `__init__()` 中注册即可。详见 `docs/plugin_development.md`。

## 许可证

MIT
```