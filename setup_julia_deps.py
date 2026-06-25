#!/usr/bin/env python3
"""
初始化 Julia 项目依赖
运行: python setup_julia_deps.py
"""

import subprocess
import sys
from pathlib import Path

JULIA_DIR = Path(__file__).parent / "julia"
PROJECT_TOML = JULIA_DIR / "Project.toml"

# 依赖列表
DEPS = [
    "HTTP",
    "JSON3",
    "Wavelets",
    "DSP",
    "TOML",
]

def run_julia(cmd: str, **kwargs):
    """在 julia/ 目录下运行 Julia 命令"""
    return subprocess.run(
        ["julia", "--project=.", "-e", cmd],
        cwd=JULIA_DIR,
        capture_output=True,
        text=True,
        **kwargs,
    )

def main():
    print("=" * 50)
    print("  AIVoiceSeamFix — Julia 依赖初始化")
    print("=" * 50)
    print()

    # 检查 julia 是否可用
    try:
        subprocess.run(["julia", "--version"], capture_output=True, check=True)
    except FileNotFoundError:
        print("❌ 找不到 julia 命令，请确认 Julia 已安装且加入 PATH")
        sys.exit(1)

    # 逐个添加依赖（比一次性数组更稳）
    for pkg in DEPS:
        print(f"📦 添加 {pkg} ... ", end="", flush=True)
        result = run_julia(f'import Pkg; Pkg.add("{pkg}")')
        if result.returncode == 0:
            print("✅")
        else:
            print(f"❌")
            print(f"    stderr: {result.stderr.strip()}")
            sys.exit(1)

    print()
    print("=" * 50)
    print("  初始化完成！")
    print()
    print("  运行测试:")
    print(f"    julia --project={JULIA_DIR} julia/test/runtests.jl")
    print("=" * 50)


if __name__ == "__main__":
    main()