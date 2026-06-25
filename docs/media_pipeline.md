# 媒体处理管线

## 输入
- 纯音频: 解码为 AudioBuffer
- 视频: FFmpeg 提取音轨 → AudioBuffer

## 输出
- WAV: 直接写入
- MP3/M4A: FFmpeg 编码
- 视频: 替换音轨后混流
