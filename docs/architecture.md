```markdown
# AIVoiceSeamFix 完整技术文档

> **版本**: 0.1.0  
> **最后更新**: 2026-06-25  
> **许可证**: MIT

---

## 目录

1. [项目概述](#1-项目概述)
2. [快速开始](#2-快速开始)
3. [系统架构](#3-系统架构)
4. [核心设计](#4-核心设计)
5. [算法原理](#5-算法原理)
6. [API 参考](#6-api-参考)
7. [开发指南](#7-开发指南)
8. [测试指南](#8-测试指南)
9. [部署与打包](#9-部署与打包)
10. [FAQ](#10-faq)

---

## 1. 项目概述

### 1.1 背景

AI 语音合成（TTS）技术已广泛应用于有声书、短视频配音、虚拟主播等场景。然而，大多数 TTS 引擎在生成较长文本时，会将文本分段处理后拼接输出。这种分段拼接在波形层面产生了**不连续点**——表现为时域上的突变、频谱上的宽带噪声，人耳感知为"毛刺"、"爆音"或"闷感"。

传统的音频编辑软件（如 Audition、PR）虽然有去噪和淡化功能，但需要手动定位每个接缝点，对于几分钟甚至几十分钟的音频来说工作量极大。

**AIVoiceSeamFix** 专门解决这个问题：自动检测 AI 配音中的断裂点，用信号处理算法平滑过渡，输出自然流畅的音频。

### 1.2 核心能力

| 功能 | 说明 |
|------|------|
| 自动检测 | 小波变换定位音频断裂点，无需人工标记 |
| 智能平滑 | 高斯卷积核局部平滑，只处理断裂区域 |
| 多格式支持 | 输入 WAV/MP3/M4A/MP4，输出 WAV/MP3/M4A |
| 视频处理 | 视频文件自动提取音轨、修复后混流回去 |
| 批量拼接 | 多段音频等功率交叉淡化拼接 |
| 可扩展 | 算法插件机制，新增算法只需实现接口 |
| 前端 GUI | 拖拽式操作，动态参数面板，原音/修复对比播放 |

### 1.3 效果对比

| 指标 | 修复前 | 修复后 |
|------|--------|--------|
| 波形连续性 | 接缝处有阶跃突变 | 平滑过渡 |
| 频谱 | 拼接点有宽带噪声 | 噪声消除 |
| 主观听感 | 发闷、有毛刺 | 清脆自然 |
| 处理速度 | - | 实时（2 秒音频 < 1 秒） |

---

## 2. 快速开始

### 2.1 环境要求

| 软件 | 最低版本 | 说明 |
|------|----------|------|
| Julia | 1.10+ | 算法后端 |
| Python | 3.10+ | GUI 前端 |
| FFmpeg | 4.0+ | 媒体编解码（需在 PATH 中） |
| 操作系统 | Windows 10+ / macOS 12+ / Linux | - |

### 2.2 安装

**第一步：克隆项目**

```bash
git clone https://github.com/your-org/AIVoiceSeamFix.git
cd AIVoiceSeamFix
```

**第二步：安装 Julia 依赖**

```bash
cd julia
julia --project=. -e 'import Pkg; Pkg.instantiate()'
cd ..
```

这会根据 `julia/Project.toml` 自动安装以下依赖：
- `HTTP.jl` — HTTP 服务器
- `JSON3.jl` — JSON 序列化
- `Wavelets.jl` — 小波变换
- `DSP.jl` — 数字信号处理（重采样、卷积）
- `TOML.jl` — 配置文件解析
- `WAV.jl` — WAV 文件读写

**第三步：创建 Python 虚拟环境**

```bash
python setup_gui_env.py
```

这会：
1. 在 `gui/.venv/` 创建独立虚拟环境
2. 安装 PyQt6 和 requests
3. 生成 `scripts/start_gui.bat`（Windows）或 `scripts/start_gui.sh`（macOS/Linux）

**第四步（可选）：生成测试音频**

```bash
python create_test_audio.py
```

在 `examples/` 目录下生成 WAV/MP3/MP4 测试文件。

### 2.3 启动

**启动 Julia 后端：**

```bash
# Windows / macOS / Linux
julia --project=julia julia/server.jl

# 指定端口
julia --project=julia julia/server.jl --port 9000
```

看到以下输出表示后端就绪：

```
==================================================
  AIVoiceSeamFix Server
  Port: 8765
  Algorithms: repair + join
==================================================
🎵 AIVoiceSeamFix API server starting on http://127.0.0.1:8765
```

**启动 Python GUI：**

```bash
# Windows
scripts\start_gui.bat

# macOS / Linux
bash scripts/start_gui.sh
```

### 2.4 第一个修复

1. 打开 GUI，确认左下角显示 "✅ 服务已连接"
2. 拖拽一个 AI 生成的 WAV/MP3 文件到拖拽区
3. 调整参数（或使用默认值）
4. 点击 "🔧 开始修复"
5. 修复完成后点击 "▶ 播放修复" 试听效果

---

## 3. 系统架构

### 3.1 整体架构图

```
┌─────────────────────────────────────────────────────────┐
│                    Python GUI (PyQt6)                    │
│  ┌─────────┐ ┌──────────┐ ┌────────┐ ┌──────────────┐  │
│  │ 拖拽上传 │ │ 参数面板  │ │ 结果面板│ │ 日志/播放器   │  │
│  └────┬─────┘ └────┬─────┘ └───┬────┘ └──────┬───────┘  │
│       │             │           │              │          │
│       └─────────────┴─────┬─────┴──────────────┘          │
│                           │                               │
│                    API Client                             │
│                    (HTTP/JSON)                            │
└───────────────────────────┬───────────────────────────────┘
                            │
┌───────────────────────────┴───────────────────────────────┐
│                   Julia HTTP Server                       │
│                  (HTTP.jl + JSON3.jl)                     │
│                                                           │
│  ┌──────────────────────────────────────────────────┐    │
│  │                  ApiPipeline                      │    │
│  │        JSON 请求 → Runner → JSON 响应             │    │
│  └──────────────────────┬───────────────────────────┘    │
│                         │                                 │
│  ┌──────────────────────┴───────────────────────────┐    │
│  │                    Runner                         │    │
│  │        查 Registry → 调 process()                 │    │
│  └──────────────────────┬───────────────────────────┘    │
│                         │                                 │
│  ┌──────────────────────┴───────────────────────────┐    │
│  │                 AlgorithmCore                     │    │
│  │  ┌────────────────┐  ┌────────────────────────┐  │    │
│  │  │ Repair 算法     │  │ Join 算法               │  │    │
│  │  │ 小波检测        │  │ 等功率交叉淡化           │  │    │
│  │  │ → 区域构建     │  │                        │  │    │
│  │  │ → 高斯平滑     │  │                        │  │    │
│  │  └────────────────┘  └────────────────────────┘  │    │
│  └──────────────────────────────────────────────────┘    │
│                         │                                 │
│  ┌──────────────────────┴───────────────────────────┐    │
│  │                   Media Layer                     │    │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────────────┐ │    │
│  │  │ FFmpeg   │ │ WAV.jl  │ │ VideoMux         │ │    │
│  │  │ 编解码    │ │ 读写     │ │ 视频音轨替换      │ │    │
│  │  └──────────┘ └──────────┘ └──────────────────┘ │    │
│  └──────────────────────────────────────────────────┘    │
└───────────────────────────────────────────────────────────┘
```

### 3.2 分层设计

项目严格遵循以下分层原则：

```
┌──────────────────────────────────────┐
│           GUI / HTTP                  │  表示层：不关心算法细节
├──────────────────────────────────────┤
│         Pipeline                      │  编排层：组合 Media + Algorithm
├──────────────────────────────────────┤
│       AlgorithmCore                   │  核心层：AudioBuffer → AlgorithmResult
│   (只处理数据类型，不碰文件/网络)      │
├──────────────────────────────────────┤
│          Media                        │  基础设施层：文件 ↔ AudioBuffer
└──────────────────────────────────────┘
```

**关键设计决策**：
- 算法模块**不依赖**文件格式、GUI、HTTP
- 新增算法只需实现 `Core/Interface.jl` 中定义的接口
- 媒体层负责所有 FFmpeg 调用，算法层永远看不到 `ffmpeg` 命令

### 3.3 数据流

```
输入文件 (mp3/mp4/wav)
  │
  ▼
MediaIO.decode_to_audiobuffer()
  │ 内部: FFmpeg → 临时 WAV → WAV.jl 读取
  │ 输出: AudioBuffer (samples::Matrix{Float64})
  │
  ▼
Runner.run_repair_algorithm()
  │ 查 Registry → 获取算法实例 → 调 process()
  │
  ▼
WaveletGaussianRepair.process()
  │ 1. 提取第一声道: audio.samples[:, 1]
  │ 2. WaveletDetector: 小波变换 → 断裂点
  │ 3. RegionBuilder:  断裂点 → RepairRegion[]
  │ 4. GaussianSmoother: 区域平滑
  │ 输出: AlgorithmResult (audio + regions + report)
  │
  ▼
ExportPipeline.export_result()
  │ 内部: AudioEncode (或 VideoMux)
  │ 输出: 修复后的文件
```

---

## 4. 核心设计

### 4.1 核心类型

#### AudioBuffer — 统一音频容器

```julia
struct AudioBuffer
    samples::Matrix{Float64}  # (sample_count × channels)
    sample_rate::Int
    channels::Int
    meta::AudioMeta
end
```

设计要点：
- `samples` 始终是 `Matrix{Float64}`，单声道也是 N×1 矩阵
- 采样率必须是正整数，声道数 ≥ 1
- `meta` 携带原始文件信息但不影响算法逻辑

#### RepairRegion — 断裂区域

```julia
struct RepairRegion
    start_sample::Int
    end_sample::Int
    center_sample::Int
    start_sec::Float64
    end_sec::Float64
    center_sec::Float64
    score::Float64     # 0.0-1.0 置信度
    label::String      # "seam", "click", "pop"
end
```

同时存储样本索引和时间，方便算法层和 UI 层各自使用。

#### AlgorithmResult — 算法输出

```julia
struct AlgorithmResult
    audio::AudioBuffer
    regions::Vector{RepairRegion}
    report::Dict{String, Any}
end
```

### 4.2 算法接口

所有算法必须实现以下接口（定义在 `Core/Interface.jl`）：

| 函数 | 返回类型 | 说明 |
|------|----------|------|
| `algorithm_id` | `String` | 唯一标识符 |
| `algorithm_name` | `String` | 可读名称 |
| `algorithm_version` | `VersionNumber` | 版本号 |
| `algorithm_mode` | `String` | "repair" 或 "join" |
| `parameter_specs` | `Vector{ParamSpec}` | 参数声明 |
| `channel_policy` | `Symbol` | `:mono` / `:passthrough` |
| `process` | `AlgorithmResult` | 算法核心逻辑 |

### 4.3 算法注册中心

```julia
const REGISTRY = AlgorithmRegistry()

function __init__()
    register_algorithm!(REGISTRY, WaveletGaussianRepairAlgorithm())
    register_algorithm!(REGISTRY, EqualPowerCrossfadeJoinAlgorithm())
end
```

GUI 通过 `GET /api/algorithms` 获取所有已注册算法及其参数声明，动态生成参数面板。

### 4.4 ParamSpec — 参数描述

```julia
struct ParamSpec
    name::Symbol
    type::DataType        # Float64, Int, String
    default::Any
    label::String
    description::String
    min::Union{Float64, Int, Nothing}
    max::Union{Float64, Int, Nothing}
    step::Union{Float64, Int, Nothing}
    choices::Union{Vector{String}, Nothing}
end
```

GUI 根据 `ParamSpec` 自动创建对应控件：
- `Float64` + `min/max/step` → 浮点滑条
- `Int` + `min/max` → 整数选择器
- `String` + `choices` → 下拉框

---

## 5. 算法原理

### 5.1 小波断裂检测 (WaveletDetector)

**问题**：AI 拼接的断裂点在时域上表现为阶跃突变，在频域上表现为宽带噪声。

**方法**：小波变换的多分辨率分析能力天然适合检测局部突变。

**步骤**：

1. **小波分解**：使用 Daubechies 4 (db4) 小波基，对音频进行 3 层离散小波变换（DWT）
2. **提取高频系数**：取第 1 层细节系数（最高频），突变在此分量上表现为局部极大值
3. **上采样**：细节系数长度 ≠ 原始长度时，用 DSP.resample 插值对齐
4. **动态阈值**：`threshold = median(detail) + sensitivity × MAD × 1.4826`
   - MAD = Median Absolute Deviation
   - 1.4826 是正态分布下 MAD→标准差的一致性常数
   - sensitivity 越大，阈值越高，检测越保守
5. **峰值检测**：高于阈值且是局部最大 → 标记为断裂点
6. **最小间隔约束**：两个断裂点至少间隔 5ms，避免重复检测

**参数**：
- `sensitivity`: 2.0（敏感）~ 20.0（保守），默认 8.0
- `wavelet`: 小波基名称，默认 "db4"

### 5.2 区域构建 (RegionBuilder)

**目的**：将孤立断裂点扩展为可修复的连续区域，并合并重叠区域。

**步骤**：

1. **扩展**：每个断裂点向两侧扩展 `expand_ms`（默认 50ms），形成宽度为 100ms 的区域
2. **合并**：相邻区域间距 < `merge_ms`（默认 80ms）时，合并为一个大区域
3. **边界裁切**：区域边界限制在 `[0, total_samples)` 内
4. **元信息**：计算区域的中心点、时间坐标、置信度评分

**参数**：
- `expand_ms`: 10 ~ 120ms，默认 50ms
- `merge_ms`: 10 ~ 200ms，默认 80ms

### 5.3 高斯卷积平滑 (GaussianSmoother)

**目的**：在修复区域内用高斯核卷积平滑波形，消除突变，同时保留区域外的原始信号。

**步骤**：

1. **窗口扩展**：对每个修复区域，向两侧再扩展 `window_ms`（默认 60ms），形成处理窗口
2. **高斯核构造**：`kernel[i] ∝ exp(-(i/sigma)²/2)`，核半径 = 3σ，核归一化
3. **卷积平滑**：处理窗口与高斯核做卷积（边缘用 padding 补齐）
4. **加权混合**：原始信号与平滑信号按高斯权重混合
   ```
   weight(t) = α × exp(-t²/(2×0.3²))   # t ∈ [-1, 1] 映射到窗口范围
   output = weight × smoothed + (1-weight) × original
   ```
   - 窗口中心：α 权重 → 平滑为主
   - 窗口边缘：权重衰减到 0 → 保留原始信号
5. **区域重叠处理**：按顺序处理，后面的区域覆盖重叠部分

**参数**：
- `window_ms`: 10 ~ 150ms，默认 60ms
- `sigma_ms`: 1 ~ 20ms，默认 4ms
- `alpha`: 0.1 ~ 0.8，默认 0.45

### 5.4 等功率交叉淡化 (EqualPowerCrossfadeJoin)

**目的**：多段音频平滑拼接，过渡区能量保持恒定。

**步骤**：

1. **统一采样率**：所有段必须同采样率
2. **计算总长度**：`total = sum(len_i) - fade_samples × (n_segments - 1)`
3. **交叉淡化**：
   ```
   fade_out(t) = cos(π × t / 2)   # 前一段淡出
   fade_in(t)  = sin(π × t / 2)   # 后一段淡入
   output = fade_out × prev + fade_in × next
   ```
   由于 `cos²(t) + sin²(t) = 1`，过渡区总能量恒定

**参数**：
- `fade_ms`: 5 ~ 120ms，默认 25ms

---

## 6. API 参考

### 6.1 端点列表

| 方法 | 路径 | 说明 |
|------|------|------|
| GET | `/api/algorithms` | 列出所有可用算法及参数 |
| POST | `/api/run` | 统一运行入口 |
| POST | `/api/repair` | 修复快捷方式 |
| POST | `/api/join` | 拼接快捷方式 |
| GET | `/api/status` | 服务状态检查 |
| POST | `/api/shutdown` | 关闭服务 |

所有响应均为 JSON 格式，包含 CORS 头。

### 6.2 GET /api/algorithms

**响应**：

```json
{
  "ok": true,
  "algorithms": [
    {
      "id": "wavelet_gaussian_repair",
      "name": "Wavelet + Gaussian Repair",
      "version": "0.1.0",
      "mode": "repair",
      "channel_policy": "mono",
      "params": [
        {
          "name": "sensitivity",
          "type": "Float64",
          "default": 8.0,
          "label": "检测灵敏度",
          "description": "数值越高，误检越少，但可能漏检",
          "min": 2.0,
          "max": 20.0,
          "step": 1.0
        }
      ]
    }
  ]
}
```

### 6.3 POST /api/run

**请求体**：

```json
{
  "mode": "repair",
  "algorithm_id": "wavelet_gaussian_repair",
  "input_path": "/path/to/input.wav",
  "output_path": "/path/to/output.wav",
  "output_format": "wav",
  "params": {
    "sensitivity": 8.0,
    "alpha": 0.45
  }
}
```

**repair 成功响应**：

```json
{
  "ok": true,
  "algorithm_id": "wavelet_gaussian_repair",
  "detected_regions": 3,
  "output_path": "/path/to/output.wav"
}
```

**join 请求**：

```json
{
  "mode": "join",
  "algorithm_id": "equal_power_crossfade_join",
  "input_paths": ["/path/001.wav", "/path/002.wav"],
  "output_path": "/path/joined.wav",
  "output_format": "wav",
  "params": {
    "fade_ms": 25.0
  }
}
```

**错误响应**：

```json
{
  "ok": false,
  "error": "描述信息"
}
```

### 6.4 POST /api/repair

快捷方式，等价于 `POST /api/run` 且 `mode="repair"`。

```json
{
  "algorithm_id": "wavelet_gaussian_repair",
  "input_path": "/path/input.wav",
  "output_path": "/path/output.wav",
  "output_format": "wav",
  "params": {}
}
```

### 6.5 POST /api/join

快捷方式，等价于 `POST /api/run` 且 `mode="join"`。

```json
{
  "algorithm_id": "equal_power_crossfade_join",
  "input_paths": ["/path/001.wav", "/path/002.wav"],
  "output_path": "/path/joined.wav",
  "params": {}
}
```

### 6.6 GET /api/status

```json
{
  "status": "running",
  "service": "AIVoiceSeamFix"
}
```

### 6.7 POST /api/shutdown

关闭服务。响应：

```json
{
  "message": "shutting down"
}
```

---

## 7. 开发指南

### 7.1 项目开发阶段

| 阶段 | 内容 | 状态 |
|------|------|------|
| Phase 1 | Core/Types.jl — 基础类型定义 | ✅ 完成 |
| Phase 2 | Core/Interface.jl — 算法接口 | ✅ 完成 |
| Phase 3 | Core/Registry.jl + Runner.jl | ✅ 完成 |
| Phase 4 | Media/FFmpegRunner + MediaProbe | ✅ 完成 |
| Phase 5 | Media/AudioDecode + AudioEncode + VideoMux | ✅ 完成 |
| Phase 6 | Algorithms/WaveletDetector | ✅ 完成 |
| Phase 7 | Algorithms/RegionBuilder + GaussianSmoother | ✅ 完成 |
| Phase 8 | Algorithms/WaveletGaussianRepair 组装 | ✅ 完成 |
| Phase 9 | Join 算法 + HTTP API | ✅ 完成 |
| Phase 10 | ExportPipeline + server.jl | ✅ 完成 |
| Phase 11 | Python GUI | ✅ 完成 |
| Phase 12 | 打包分发 | 📋 计划中 |
| Phase 13 | Stage 级接口开放 | 📋 计划中 |

### 7.2 新增算法

**步骤**：

1. 在 `julia/src/Algorithms/Repair/`（或 `Join/`）下创建新文件
2. 定义 struct 继承对应抽象类型：

```julia
module MySpectralRepair

import ...AIVoiceSeamFix
import ...AIVoiceSeamFix: AudioBuffer, AlgorithmResult, RepairRegion,
                          ParamSpec, AbstractRepairAlgorithm, AlgorithmContext
import ...AIVoiceSeamFix: algorithm_id, algorithm_name, algorithm_version,
                          algorithm_mode, parameter_specs, process

export MySpectralRepairAlgorithm

struct MySpectralRepairAlgorithm <: AbstractRepairAlgorithm end

algorithm_id(::MySpectralRepairAlgorithm) = "my_spectral_repair"
algorithm_name(::MySpectralRepairAlgorithm) = "My Spectral Repair"
algorithm_version(::MySpectralRepairAlgorithm) = v"0.1.0"
algorithm_mode(::MySpectralRepairAlgorithm) = "repair"

function parameter_specs(::MySpectralRepairAlgorithm)
    return [
        ParamSpec(
            name = :strength,
            type = Float64,
            default = 0.5,
            label = "修复强度",
            min = 0.0,
            max = 1.0,
            step = 0.05,
        ),
    ]
end

function process(
    algorithm::MySpectralRepairAlgorithm,
    audio::AudioBuffer,
    params::Dict{Symbol, Any},
    ctx::AlgorithmContext,
)::AlgorithmResult
    # 算法逻辑
    y = audio.samples[:, 1]
    fs = audio.sample_rate

    # ... 你的处理逻辑 ...

    out_audio = AudioBuffer(reshape(y, :, 1), fs, 1, audio.meta)
    return AlgorithmResult(
        audio = out_audio,
        regions = RepairRegion[],
        report = Dict{String, Any}("algorithm_id" => algorithm_id(algorithm)),
    )
end

end
```

3. 在 `julia/src/AIVoiceSeamFix.jl` 中 include 新文件
4. 在 `__init__()` 中注册：

```julia
register_algorithm!(REGISTRY, MySpectralRepair.MySpectralRepairAlgorithm())
```

5. 添加测试

### 7.3 Stage 级接口（计划中）

未来计划开放内部 Stage 接口，允许自由组合检测器和修复器：

```
Detector → RegionBuilder → Repairer
```

```julia
abstract type AbstractDetector end
abstract type AbstractRegionBuilder end
abstract type AbstractRepairer end
abstract type AbstractJoiner end

detect(detector, audio, params, ctx) → Vector{Int}
build_regions(builder, points, audio, params, ctx) → Vector{RepairRegion}
repair(repairer, audio, regions, params, ctx) → Vector{Float64}
join(joiner, audios, params, ctx) → Vector{Float64}
```

这样就能实现：
- `WaveletDetector + SpectralInpainter`
- `EnergyDetector + GaussianLocalSmoother`
- `KnownTimestampDetector + CrossfadeRepairer`

### 7.4 代码规范

- Julia 文件使用 4 空格缩进
- 函数名使用 `snake_case`
- 模块名使用 `CamelCase`
- 公开 API 始终标注类型签名
- 每个公开函数必须有 docstring
- 提交前运行 `julia --project=julia julia/test/runtests.jl`

---

## 8. 测试指南

### 8.1 运行全部测试

```bash
julia --project=julia julia/test/runtests.jl
```

### 8.2 测试覆盖

| 测试文件 | 测试内容 | 测试数 |
|----------|----------|--------|
| test_types.jl | AudioBuffer, RepairRegion 构造/验证 | ~55 |
| test_interface.jl | 算法接口合规性 | ~40 |
| test_registry.jl | 注册中心 CRUD | ~25 |
| test_runner.jl | Runner 调度逻辑 | ~20 |
| test_media_probe.jl | FFprobe 调用, 元数据解析 | ~20 |
| test_audio_decode.jl | 多格式解码 | ~15 |
| test_audio_encode.jl | 编码往返测试 | ~10 |
| test_detector.jl | 小波检测（人工信号） | ~15 |
| test_region_builder.jl | 区域扩展/合并 | ~15 |
| test_smoother.jl | 高斯平滑效果 | ~15 |
| test_pipeline.jl | 端到端修复流程 | ~15 |
| test_crossfade.jl | 等功率交叉淡化 | ~15 |
| test_export.jl | 导出多格式 | ~10 |

### 8.3 编写测试

```julia
using Test
using AIVoiceSeamFix

@testset "my feature" begin
    @test 1 + 1 == 2
    @test_throws ArgumentError some_bad_call()
end
```

测试文件放在 `julia/test/`，以 `test_` 开头。

---

## 9. 部署与打包

### 9.1 开发环境

```bash
# 终端 1
julia --project=julia julia/server.jl

# 终端 2
source gui/.venv/bin/activate  # 或 gui\.venv\Scripts\activate
python gui/main.py
```

### 9.2 生产部署

**方式一：systemd 服务（Linux）**

```ini
# /etc/systemd/system/aivoiceseamfix.service
[Unit]
Description=AIVoiceSeamFix API Server
After=network.target

[Service]
ExecStart=/usr/bin/julia --project=/opt/AIVoiceSeamFix/julia /opt/AIVoiceSeamFix/julia/server.jl
WorkingDirectory=/opt/AIVoiceSeamFix
Restart=always
User=aivoiceseamfix

[Install]
WantedBy=multi-user.target
```

**方式二：Docker**

```dockerfile
FROM julia:1.10-bullseye

RUN apt-get update && apt-get install -y ffmpeg python3 python3-pip

WORKDIR /app
COPY . .

RUN cd julia && julia --project=. -e 'import Pkg; Pkg.instantiate()'
RUN python3 setup_gui_env.py

EXPOSE 8765
CMD ["julia", "--project=julia", "julia/server.jl"]
```

### 9.3 GUI 打包（计划中）

使用 PyInstaller 打包为独立可执行文件：

```bash
pip install pyinstaller
pyinstaller --onefile --windowed gui/main.py
```

---

## 10. FAQ

### Q: 修复后声音变闷怎么办？

降低 `alpha` 参数（如从 0.45 降到 0.2），减少平滑强度。

### Q: 有些断裂点没检测到？

降低 `sensitivity` 参数（如从 8.0 降到 4.0），提高检测灵敏度。

### Q: 正常区域也被误检为断裂点？

提高 `sensitivity` 参数（如从 8.0 升到 14.0）。

### Q: 支持哪些输入格式？

WAV, MP3, M4A, AAC, FLAC, OGG, MP4, MOV。视频文件会自动提取音轨处理。

### Q: 处理速度如何？

实时处理。2 秒音频 < 1 秒（取决于 CPU 和采样率）。

### Q: 能处理多声道音频吗？

当前版本降混为单声道处理。多声道支持在计划中。

### Q: 如何添加新的修复算法？

参见 [7.2 新增算法](#72-新增算法)。

### Q: Julia 后端启动失败？

检查：
1. Julia 版本 ≥ 1.10
2. `julia/` 目录下已执行 `Pkg.instantiate()`
3. 端口 8765 未被占用
4. FFmpeg 在 PATH 中可用

### Q: GUI 连不上后端？

确认：
1. Julia 后端已启动
2. 端口一致（默认 8765）
3. 防火墙未拦截本地连接
4. 点击"🔄 刷新算法"按钮重试

---

## 附录

### A. 依赖列表

**Julia**:
- HTTP.jl — HTTP 服务器
- JSON3.jl — JSON 处理
- Wavelets.jl — 小波变换
- DSP.jl — 数字信号处理
- TOML.jl — 配置文件
- WAV.jl — WAV 读写

**Python**:
- PyQt6 — GUI 框架
- requests — HTTP 客户端

**系统**:
- FFmpeg — 音频/视频编解码
- FFprobe — 媒体信息探测

### B. 贡献者

项目由社区贡献驱动。欢迎提交 Issue 和 Pull Request。

### C. 许可证

MIT License — 详见 LICENSE 文件。
```