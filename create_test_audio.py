#!/usr/bin/env python3
"""生成 Phase 4 测试用的音频文件"""

import struct
import wave
import subprocess
from pathlib import Path

ROOT = Path(__file__).parent
EXAMPLES = ROOT / "examples"
SEGMENTS = EXAMPLES / "segments"
EXAMPLES.mkdir(parents=True, exist_ok=True)
SEGMENTS.mkdir(parents=True, exist_ok=True)

def make_wav(path, duration_sec=2.0, sample_rate=44100, channels=1):
    """生成一个简单的正弦波 WAV 文件"""
    import math
    n_samples = int(sample_rate * duration_sec)
    freq = 440.0  # A4
    samples = []
    for i in range(n_samples):
        t = i / sample_rate
        value = int(32767 * 0.5 * math.sin(2 * math.pi * freq * t))
        samples.append(value)

    with wave.open(str(path), 'w') as wf:
        wf.setnchannels(channels)
        wf.setsampwidth(2)  # 16-bit
        wf.setframerate(sample_rate)
        wf.writeframes(struct.pack(f'<{len(samples)}h', *samples))
    print(f"✅ {path}")

def make_mp3(wav_path, mp3_path):
    """用 ffmpeg 将 WAV 转 MP3"""
    if not wav_path.exists():
        print(f"❌ {wav_path} not found, skipping {mp3_path}")
        return
    subprocess.run(
        ["ffmpeg", "-y", "-i", str(wav_path), "-b:a", "128k", str(mp3_path)],
        capture_output=True,
    )
    print(f"✅ {mp3_path}")

def make_mp4(wav_path, mp4_path):
    """用 ffmpeg 生成带音轨的 MP4（黑屏视频 + 音频）"""
    if not wav_path.exists():
        print(f"❌ {wav_path} not found, skipping {mp4_path}")
        return
    subprocess.run(
        ["ffmpeg", "-y",
         "-f", "lavfi", "-i", "color=c=black:s=320x240:d=2",
         "-i", str(wav_path),
         "-c:v", "libx264", "-c:a", "aac",
         "-shortest", str(mp4_path)],
        capture_output=True,
    )
    print(f"✅ {mp4_path}")

# 1. 生成基础 WAV 文件
repair_wav = EXAMPLES / "repair_input.wav"
make_wav(repair_wav, duration_sec=2.0)

# 2. 转 MP3
make_mp3(repair_wav, EXAMPLES / "repair_input.mp3")

# 3. 生成带视频的 MP4
make_mp4(repair_wav, EXAMPLES / "repair_input.mp4")

# 4. 生成分段文件
for i, name in enumerate(["001.wav", "002.mp3", "003.m4a"], 1):
    seg_wav = SEGMENTS / f"seg_{i}.wav"
    make_wav(seg_wav, duration_sec=1.0)
    target = SEGMENTS / name
    if name.endswith(".mp3"):
        make_mp3(seg_wav, target)
    elif name.endswith(".m4a"):
        subprocess.run(
            ["ffmpeg", "-y", "-i", str(seg_wav), "-c:a", "aac", str(target)],
            capture_output=True,
        )
        print(f"✅ {target}")
    else:
        # 直接复制 wav
        import shutil
        shutil.copy(seg_wav, target)
        print(f"✅ {target}")
    seg_wav.unlink()  # 清理临时文件

print("\n🎵 测试音频文件生成完毕")