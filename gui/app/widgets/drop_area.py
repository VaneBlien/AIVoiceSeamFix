"""拖拽上传区域"""

from PyQt6.QtWidgets import QLabel, QFileDialog
from PyQt6.QtCore import pyqtSignal, Qt


class DropArea(QLabel):
    file_dropped = pyqtSignal(str)

    def __init__(self):
        super().__init__()
        self.setText("拖拽音频文件到此处\n(支持 WAV / MP3 / M4A / MP4)")
        self.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.setMinimumHeight(120)
        self.setStyleSheet("""
            QLabel {
                border: 2px dashed #888;
                border-radius: 10px;
                background: #f5f5f5;
                font-size: 14px;
                color: #666;
            }
            QLabel:hover {
                border-color: #4a90d9;
                background: #e8f0fe;
            }
        """)
        self.setAcceptDrops(True)
        self.file_name = ""

    def set_file_name(self, name):
        self.file_name = name
        self.setText(f"📁 {name}")

    def dragEnterEvent(self, event):
        if event.mimeData().hasUrls():
            event.accept()
        else:
            event.ignore()

    def dropEvent(self, event):
        urls = event.mimeData().urls()
        if urls:
            path = urls[0].toLocalFile()
            self.file_dropped.emit(path)

    def mousePressEvent(self, event):
        path, _ = QFileDialog.getOpenFileName(
            self, "选择音频文件", "",
            "音频文件 (*.wav *.mp3 *.m4a *.mp4 *.aac *.flac *.ogg);;所有文件 (*)",
        )
        if path:
            self.file_dropped.emit(path)