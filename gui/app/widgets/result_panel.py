"""结果面板"""

from PyQt6.QtWidgets import QWidget, QVBoxLayout, QLabel, QFrame
from PyQt6.QtCore import Qt


class ResultPanel(QFrame):
    def __init__(self):
        super().__init__()
        self.setFrameStyle(QFrame.Shape.StyledPanel)
        layout = QVBoxLayout(self)
        layout.setSpacing(4)

        title = QLabel("📊 文件信息 / 修复结果")
        title.setStyleSheet("font-weight: bold;")
        layout.addWidget(title)

        self.info_label = QLabel("拖拽文件以查看信息")
        self.info_label.setWordWrap(True)
        layout.addWidget(self.info_label)

        self.result_label = QLabel("")
        self.result_label.setWordWrap(True)
        layout.addWidget(self.result_label)

        layout.addStretch()

    def show_file_info(self, info: dict):
        lines = []
        if info.get("format_name"):
            lines.append(f"格式: {info['format_name']}")
        if info.get("duration_sec"):
            lines.append(f"时长: {info['duration_sec']:.2f}s")
        if info.get("sample_rate"):
            lines.append(f"采样率: {info['sample_rate']} Hz")
        if info.get("channels"):
            lines.append(f"声道: {info['channels']}")
        if info.get("has_video"):
            lines.append("包含视频轨")
        self.info_label.setText("\n".join(lines) if lines else "无法获取文件信息")

    def show_result(self, result: dict):
        lines = []
        if result.get("algorithm_id"):
            lines.append(f"算法: {result['algorithm_id']}")
        if result.get("detected_regions") is not None:
            lines.append(f"检测断裂区域: {result['detected_regions']}")
        if result.get("output_path"):
            lines.append(f"输出: {result['output_path']}")
        self.result_label.setText("\n".join(lines))