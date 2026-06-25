#!/usr/bin/env python3
"""创建 Python GUI 虚拟环境并安装依赖"""

import subprocess
import sys
import venv
from pathlib import Path

ROOT = Path(__file__).parent
VENV_DIR = ROOT / "gui" / ".venv"

def main():
    print("=" * 50)
    print("  AIVoiceSeamFix — Python GUI 环境初始化")
    print("=" * 50)
    print()

    # 创建虚拟环境
    if VENV_DIR.exists():
        print(f"⚠️  虚拟环境已存在: {VENV_DIR}")
    else:
        print(f"📦 创建虚拟环境: {VENV_DIR}")
        venv.create(VENV_DIR, with_pip=True)
        print("✅ 虚拟环境创建完成")

    # pip 路径
    if sys.platform == "win32":
        pip = str(VENV_DIR / "Scripts" / "pip.exe")
        python = str(VENV_DIR / "Scripts" / "python.exe")
        activate = str(VENV_DIR / "Scripts" / "activate")
    else:
        pip = str(VENV_DIR / "bin" / "pip")
        python = str(VENV_DIR / "bin" / "python")
        activate = str(VENV_DIR / "bin" / "activate")

    # 升级 pip（用 python -m pip 方式）
    print("\n📦 升级 pip ...")
    try:
        subprocess.run([python, "-m", "pip", "install", "--upgrade", "pip"], check=True)
    except subprocess.CalledProcessError:
        print("⚠️  pip 升级跳过（不影响使用）")

    # 安装依赖
    print("\n📦 安装 PyQt6, requests ...")
    subprocess.run([python, "-m", "pip", "install", "PyQt6", "requests"], check=True)
    print("✅ 依赖安装完成")

    # 启动脚本
    if sys.platform == "win32":
        start_script = ROOT / "scripts" / "start_gui.bat"
        start_script.parent.mkdir(parents=True, exist_ok=True)
        start_script.write_text(
            f"@echo off\n"
            f"cd /d {ROOT / 'gui'}\n"
            f"call {activate}\n"
            f"python main.py\n"
            f"pause\n"
        )
        print(f"✅ 启动脚本: {start_script}")
    else:
        start_script = ROOT / "scripts" / "start_gui.sh"
        start_script.parent.mkdir(parents=True, exist_ok=True)
        start_script.write_text(
            f"#!/bin/bash\n"
            f"cd {ROOT / 'gui'}\n"
            f"source {activate}\n"
            f"python main.py\n"
        )
        start_script.chmod(0o755)
        print(f"✅ 启动脚本: {start_script}")

    print()
    print("=" * 50)
    print("  初始化完成！")
    print()
    if sys.platform == "win32":
        print(f"  1. 启动 Julia:  julia --project=julia julia/server.jl")
        print(f"  2. 启动 GUI:    {start_script}")
    else:
        print(f"  1. 启动 Julia:  julia --project=julia julia/server.jl")
        print(f"  2. 启动 GUI:    bash {start_script}")
    print("=" * 50)


if __name__ == "__main__":
    main()