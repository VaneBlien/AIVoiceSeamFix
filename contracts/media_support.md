# 媒体格式支持

## 输入
- WAV, MP3, M4A, AAC, FLAC, OGG
- MP4, MOV（提取音轨处理）

## 输出
- WAV（无损）
- MP3（有损）
- M4A（AAC）

## 规则
- 视频 → 分离音轨 → 修复 → 混回流
- 多声道 → 按 channel_policy 处理
