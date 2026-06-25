```markdown
<div align="center">

<img src="docs/logo.png" alt="AIVoiceSeamFix" width="200"/>

# AIVoiceSeamFix

**AI 配音断裂点自动检测与平滑修复**

[![Julia](https://img.shields.io/badge/Julia-1.10+-9558B2?logo=julia&logoColor=white)](https://julialang.org/)
[![Python](https://img.shields.io/badge/Python-3.10+-3776AB?logo=python&logoColor=white)](https://www.python.org/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Tests](https://img.shields.io/badge/tests-270+-passed-brightgreen)]()
[![Platform](https://img.shields.io/badge/platform-Windows%20%7C%20macOS%20%7C%20Linux-lightgrey)]()

</div>

---

## 📖 目录

- [概述](#概述)
- [效果演示](#效果演示)
- [系统架构](#系统架构)
- [快速开始](#快速开始)
- [API 参考](#api-参考)
- [算法参数](#算法参数)
- [项目结构](#项目结构)
- [开发指南](#开发指南)
- [测试](#测试)
- [路线图](#路线图)
- [贡献](#贡献)
- [许可证](#许可证)

---

## 概述

### 背景

AI 语音合成（TTS）引擎在生成长文本时，通常将其分段处理后拼接输出。这一过程在波形层面引入了**不连续点**——时域阶跃突变、频域宽带噪声，主观感知为"毛刺"、"爆音"或"闷感"。

传统修复手段依赖音频编辑软件（Audition、Premiere Pro）的手动操作，对于分钟级以上的音频效率极低。

**AIVoiceSeamFix** 将这一流程自动化：通过**小波变换**在时频域精确定位断裂点，再用**高斯卷积核**在局部区域平滑过渡，输出自然流畅的音频。

### 技术路线

| 阶段 | 方法 | 作用 |
|------|------|------|
| 检测 | 离散小波变换 (DWT, db4) | 提取高频细节分量，定位局部突变 |
| 区域构建 | 自适应扩展 + 合并 | 将孤立断裂点扩展为连续修复区域 |
| 修复 | 高斯卷积 + 加权混合 | 平滑过渡，边缘保留原始信号 |
| 拼接 | 等功率交叉淡化 | 多段音频无缝衔接 |

### 特性

- ✅ **全自动检测** — 无需手动标记断裂位置
- ✅ **局部修复** — 仅处理断裂邻域，保留非破损区域原样
- ✅ **多格式支持** — 输入 WAV/MP3/M4A/MP4，输出 WAV/MP3/M4A
- ✅ **视频处理** — 自动提取视频音轨，修复后回灌
- ✅ **批量拼接** — 多段音频等功率交叉淡化
- ✅ **可扩展架构** — 算法插件化，新增算法只需实现标准接口
- ✅ **前后端分离** — Julia 计算服务 + Python GUI，解耦可独立部署
- ✅ **完整测试** — 270+ 单元测试，覆盖核心路径

---

## 效果演示

| 修复前 | 修复后 |
|--------|--------|
| 接缝处有可闻"咔嚓"声，波形可见明显阶跃 | 过渡平滑自然，波形连续 |

```
修复前: ▁▁▁▁▁▁▁▁|▔▔▔▔▔▔▔▔  ← 阶跃突变
修复后: ▁▁▁▁▁▁▁▂▃▄▅▆▇█▔▔▔  ← 平滑过渡
```

<details>
<summary>📊 波形对比图（点击展开）</summary>

```
原音波形 (接缝处放大):
░░░░░░░░░░░░░░░░░░░░│████████████████████
                     ↑ 断裂点

修复后波形:
░░░░░░░░░░░░░░░░░▄▄▄▆▆██████████████████
                  ↑ 平滑过渡区
```

</details>

---

## 系统架构

### 分层设计

```
┌──────────────────────────────────────────────┐
│            表示层 (GUI / HTTP)                 │
│  Python PyQt6  /  Julia HTTP.jl              │
├──────────────────────────────────────────────┤
│            编排层 (Pipeline)                  │
│  ApiPipeline  /  ExportPipeline              │
├──────────────────────────────────────────────┤
│            算法核心层 (AlgorithmCore)          │
│  AudioBuffer → AlgorithmResult               │
│  不依赖文件格式 / GUI / HTTP                  │
├──────────────────────────────────────────────┤
│            基础设施层 (Media)                  │
│  FFmpegRunner / AudioDecode / AudioEncode    │
└──────────────────────────────────────────────┘
```

### 数据流

```
输入文件 (mp3/mp4/wav)
       │
       ▼
  MediaIO.decode_to_audiobuffer()
       │  FFmpeg → 临时 WAV → AudioBuffer
       ▼
  Runner.run_repair_algorithm()
       │  Registry 查找 → process()
       ▼
  WaveletGaussianRepair.process()
       │  1. WaveletDetector   — 小波变换 → 断裂点
       │  2. RegionBuilder     — 断裂点 → RepairRegion[]
       │  3. GaussianSmoother  — 高斯卷积平滑
       ▼
  ExportPipeline.export_result()
       │  AudioEncode / VideoMux
       ▼
 输出文件 (wav/mp3/m4a/mp4)
```

---

## 快速开始

### 环境依赖

| 软件 | 版本要求 | 用途 |
|------|----------|------|
| Julia | ≥ 1.10 | 算法计算引擎 |
| Python | ≥ 3.10 | GUI 前端 |
| FFmpeg | ≥ 4.0 | 音频/视频编解码 |
| FFprobe | ≥ 4.0 | 媒体元数据探测 |

> FFmpeg/FFprobe 需在系统 PATH 中可调用。

### 安装步骤

```bash
# 1. 克隆仓库
git clone https://github.com/your-org/AIVoiceSeamFix.git
cd AIVoiceSeamFix

# 2. 安装 Julia 依赖
cd julia
julia --project=. -e 'import Pkg; Pkg.instantiate()'
cd ..

# 3. 创建 Python 虚拟环境并安装依赖
python setup_gui_env.py

# 4. (可选) 生成测试音频
python create_test_audio.py
```

### 启动服务

**终端 1 — Julia 后端**：

```bash
julia --project=julia julia/server.jl

# 自定义端口
julia --project=julia julia/server.jl --port 9000
```

**终端 2 — Python GUI**：

```bash
# Windows
scripts\start_gui.bat

# macOS / Linux
bash scripts/start_gui.sh
```

### 运行测试

```bash
julia --project=julia julia/test/runtests.jl
```

---

## API 参考

### 端点概览

| 方法 | 路径 | 描述 |
|------|------|------|
| `GET` | `/api/algorithms` | 查询所有已注册算法及其参数 |
| `POST` | `/api/run` | 统一运行入口（repair / join） |
| `POST` | `/api/repair` | 修复快捷方式 |
| `POST` | `/api/join` | 拼接快捷方式 |
| `GET` | `/api/status` | 服务健康检查 |
| `POST` | `/api/shutdown` | 安全关闭服务 |

### GET /api/algorithms

返回所有可用算法及其参数规格。

```bash
curl http://127.0.0.1:8765/api/algorithms
```

<details>
<summary>响应示例</summary>

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
        },
        {
          "name": "alpha",
          "type": "Float64",
          "default": 0.45,
          "label": "平滑强度",
          "description": "0=保持原样，1=完全平滑",
          "min": 0.1,
          "max": 0.8,
          "step": 0.05
        }
      ]
    },
    {
      "id": "equal_power_crossfade_join",
      "name": "Equal-Power Crossfade Join",
      "version": "0.1.0",
      "mode": "join",
      "channel_policy": "mono",
      "params": [
        {
          "name": "fade_ms",
          "type": "Float64",
          "default": 25.0,
          "label": "Crossfade 时长 (ms)",
          "min": 5.0,
          "max": 120.0,
          "step": 5.0
        }
      ]
    }
  ]
}
```

</details>

### POST /api/run

统一运行接口。

**Repair 请求**：

```bash
curl -X POST http://127.0.0.1:8765/api/run \
  -H "Content-Type: application/json" \
  -d '{
    "mode": "repair",
    "algorithm_id": "wavelet_gaussian_repair",
    "input_path": "/path/to/input.wav",
    "output_path": "/path/to/output.wav",
    "output_format": "wav",
    "params": {
      "sensitivity": 8.0,
      "alpha": 0.45
    }
  }'
```

**Join 请求**：

```bash
curl -X POST http://127.0.0.1:8765/api/run \
  -H "Content-Type: application/json" \
  -d '{
    "mode": "join",
    "algorithm_id": "equal_power_crossfade_join",
    "input_paths": ["/path/seg1.wav", "/path/seg2.wav"],
    "output_path": "/path/joined.wav",
    "params": {
      "fade_ms": 25.0
    }
  }'
```

**响应**：

```json
{
  "ok": true,
  "algorithm_id": "wavelet_gaussian_repair",
  "detected_regions": 3,
  "output_path": "/path/to/output.wav"
}
```

---

## 算法参数

### wavelet_gaussian_repair

| 参数 | 类型 | 默认值 | 范围 | 说明 |
|------|------|--------|------|------|
| `sensitivity` | Float64 | 8.0 | 2.0 – 20.0 | 检测灵敏度。越低越敏感，可能误检；越高越保守，可能漏检 |
| `expand_ms` | Float64 | 50.0 | 10.0 – 120.0 | 断裂点向两侧扩展宽度 (ms) |
| `merge_ms` | Float64 | 80.0 | 10.0 – 200.0 | 相邻区域间距小于此值时合并 (ms) |
| `window_ms` | Float64 | 60.0 | 10.0 – 150.0 | 高斯平滑窗口半宽 (ms) |
| `sigma_ms` | Float64 | 4.0 | 1.0 – 20.0 | 高斯核标准差 (ms) |
| `alpha` | Float64 | 0.45 | 0.1 – 0.8 | 平滑强度。0=保持原样，1=完全平滑 |

### equal_power_crossfade_join

| 参数 | 类型 | 默认值 | 范围 | 说明 |
|------|------|--------|------|------|
| `fade_ms` | Float64 | 25.0 | 5.0 – 120.0 | 交叉淡化时长 (ms) |

---

## 项目结构

```
AIVoiceSeamFix/
│
├── julia/                          # Julia 计算后端
│   ├── server.jl                   # HTTP 服务入口
│   ├── Project.toml                # Julia 依赖声明
│   └── src/
│       ├── AIVoiceSeamFix.jl       # 顶层模块 + Registry 初始化
│       │
│       ├── Core/                   # 核心抽象层
│       │   ├── Types.jl            # AudioBuffer, RepairRegion, AlgorithmResult
│       │   ├── Params.jl           # ParamSpec 参数描述 + 验证
│       │   ├── Interface.jl        # 抽象算法接口定义
│       │   ├── Registry.jl         # 算法注册中心
│       │   ├── Runner.jl           # 统一调度入口
│       │   └── Errors.jl           # 错误类型层次
│       │
│       ├── Media/                  # 媒体 IO 层
│       │   ├── FFmpegRunner.jl     # FFmpeg / FFprobe 命令封装
│       │   ├── MediaProbe.jl       # 媒体元数据提取
│       │   ├── AudioDecode.jl      # 任意格式 → AudioBuffer
│       │   ├── AudioEncode.jl      # AudioBuffer → 文件
│       │   ├── VideoMux.jl         # 视频音轨替换
│       │   └── MediaIO.jl          # 统一 IO 门面
│       │
│       ├── Algorithms/             # 算法实现
│       │   ├── Common/
│       │   │   └── Kernels.jl      # 高斯核等通用信号处理工具
│       │   ├── Repair/
│       │   │   ├── WaveletDetector.jl       # 小波断裂检测
│       │   │   ├── RegionBuilder.jl         # 断裂区域构建
│       │   │   ├── GaussianSmoother.jl      # 高斯卷积平滑
│       │   │   └── WaveletGaussianRepair.jl # 完整修复算法组装
│       │   └── Join/
│       │       └── EqualPowerCrossfadeJoin.jl # 等功率交叉淡化
│       │
│       ├── Pipeline/               # 编排层
│       │   ├── ApiPipeline.jl      # HTTP 请求 → Runner → 响应
│       │   └── ExportPipeline.jl   # AlgorithmResult → 文件输出
│       │
│       ├── Server/
│       │   └── ApiServer.jl        # HTTP 路由 + CORS + 生命周期
│       │
│       └── test/                   # 单元测试 (270+ cases)
│           ├── runtests.jl
│           ├── test_types.jl
│           ├── test_interface.jl
│           ├── test_registry.jl
│           ├── test_runner.jl
│           ├── test_media_probe.jl
│           ├── test_audio_decode.jl
│           ├── test_audio_encode.jl
│           ├── test_detector.jl
│           ├── test_region_builder.jl
│           ├── test_smoother.jl
│           ├── test_pipeline.jl
│           ├── test_crossfade.jl
│           └── test_export.jl
│
├── gui/                            # Python 桌面 GUI
│   ├── main.py                     # 应用入口
│   ├── requirements.txt            # Python 依赖
│   └── app/
│       ├── main_window.py          # 主窗口布局
│       ├── services/
│       │   ├── api_client.py       # Julia 后端 HTTP 客户端
│       │   ├── file_manager.py     # 文件路径管理
│       │   └── audio_player.py     # 系统音频播放器
│       ├── workers/
│       │   ├── repair_worker.py    # 后台修复线程
│       │   └── probe_worker.py     # 后台媒体探测线程
│       └── widgets/
│           ├── drop_area.py        # 拖拽上传组件
│           ├── params_panel.py     # 动态参数面板
│           ├── result_panel.py     # 结果展示
│           └── log_panel.py        # 操作日志
│
├── config/
│   └── default.toml                # 默认配置文件
│
├── contracts/                      # 接口规范
│   ├── api_schema.md               # API 契约
│   ├── media_support.md            # 媒体格式支持
│   └── algorithm_interface.md      # 算法接口规范
│
├── docs/                           # 技术文档
│   ├── architecture.md             # 系统架构
│   ├── algorithm.md                # 算法原理
│   ├── media_pipeline.md           # 媒体处理管线
│   ├── plugin_development.md       # 算法开发指南
│   └── roadmap.md                  # 路线图
│
├── scripts/                        # 启停脚本
│   ├── start_gui.bat / .sh         # GUI 启动
│   └── dev_run_julia.sh            # Julia 开发启动
│
├── examples/                       # 测试音频素材
│   ├── repair_input.wav
│   ├── repair_input.mp3
│   ├── repair_input.mp4
│   └── segments/
│
├── output/                         # 修复输出目录
├── temp/                           # 临时文件
├── logs/                           # 日志
│
├── setup_gui_env.py                # GUI 环境初始化脚本
├── create_test_audio.py            # 测试音频生成脚本
├── README.md                       # 本文件
├── LICENSE                         # MIT
└── .gitignore
```

---

## 开发指南

### 新增算法

只需实现 `Core/Interface.jl` 中定义的抽象接口：

```julia
# 1. 定义算法结构体
struct MySpectralRepair <: AbstractRepairAlgorithm end

# 2. 实现必需的接口方法
algorithm_id(::MySpectralRepair) = "my_spectral_repair"
algorithm_name(::MySpectralRepair) = "My Spectral Repair"
algorithm_mode(::MySpectralRepair) = "repair"

function parameter_specs(::MySpectralRepair)
    return [
        ParamSpec(
            name = :strength,
            type = Float64,
            default = 0.5,
            label = "强度",
            min = 0.0, max = 1.0, step = 0.05,
        ),
    ]
end

# 3. 实现核心处理逻辑
function process(
    algorithm::MySpectralRepair,
    audio::AudioBuffer,
    params::Dict{Symbol, Any},
    ctx::AlgorithmContext,
)::AlgorithmResult
    # 你的修复逻辑
    return AlgorithmResult(audio = processed_audio, ...)
end
```

然后在 `AIVoiceSeamFix.jl` 中 include 并注册：

```julia
include("Algorithms/Repair/MySpectralRepair.jl")

function __init__()
    # ...
    register_algorithm!(REGISTRY, MySpectralRepair.MySpectralRepairAlgorithm())
end
```

GUI 会自动通过 `/api/algorithms` 发现新算法并生成参数面板。

### 运行测试

```bash
# 全部测试
julia --project=julia julia/test/runtests.jl

# 单个测试文件
julia --project=julia -e 'include("julia/test/test_detector.jl")'
```

---

## 测试

| 测试模块 | 测试数 | 覆盖内容 |
|----------|--------|----------|
| Types | 55 | AudioBuffer / RepairRegion 构造与验证 |
| Interface | 40 | 算法接口合规性、默认实现 |
| Registry | 25 | 注册、查询、按模式筛选 |
| Runner | 20 | 调度逻辑、模式匹配、错误处理 |
| MediaProbe | 20 | FFprobe 调用、元数据解析 |
| AudioDecode | 15 | WAV/MP3/MP4 解码 |
| AudioEncode | 10 | WAV/MP3/M4A 编码往返 |
| WaveletDetector | 15 | 人工信号断裂检测 |
| RegionBuilder | 15 | 区域扩展、合并、边界裁切 |
| GaussianSmoother | 15 | 平滑效果、参数影响 |
| Pipeline | 15 | 端到端修复流程 |
| CrossfadeJoin | 15 | 等功率交叉淡化 |
| Export | 10 | 多格式导出 |

---

## 路线图

- [x] **v0.1.0** — 小波检测 + 高斯平滑修复, HTTP API, Python GUI
- [ ] **v0.2.0** — 频谱修复算法、批量处理
- [ ] **v0.3.0** — Stage 级接口（Detector / RegionBuilder / Repairer 可替换组合）
- [ ] **v0.4.0** — 神经网络去噪插件
- [ ] **v1.0.0** — 独立安装包、多语言支持

---

## 贡献

欢迎提交 Issue 和 Pull Request。

1. Fork 本仓库
2. 创建特性分支 (`git checkout -b feature/amazing-feature`)
3. 提交更改 (`git commit -m 'Add amazing feature'`)
4. 推送到分支 (`git push origin feature/amazing-feature`)
5. 创建 Pull Request

提交前请确保 `julia --project=julia julia/test/runtests.jl` 全部通过。

---

## 许可证

本项目采用 [MIT License](LICENSE)。

---

<div align="center">

**⭐ 如果这个项目对你有帮助，请点个 Star**

</div>
```
