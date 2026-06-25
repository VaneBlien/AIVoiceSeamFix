"""日志面板"""

from PyQt6.QtWidgets import QTextEdit, QFrame, QVBoxLayout, QLabel
from datetime import datetime


class LogPanel(QFrame):
    def __init__(self):
        super().__init__()
        self.setFrameStyle(QFrame.Shape.StyledPanel)
        layout = QVBoxLayout(self)
        layout.setSpacing(4)

        title = QLabel("📝 日志")
        title.setStyleSheet("font-weight: bold;")
        layout.addWidget(title)

        self.text = QTextEdit()
        self.text.setReadOnly(True)
        self.text.setMaximumHeight(120)
        self.text.setStyleSheet("background: #1e1e1e; color: #d4d4d4; font-family: Consolas; font-size: 12px;")
        layout.addWidget(self.text)

    def add_message(self, message: str):
        timestamp = datetime.now().strftime("%H:%M:%S")
        self.text.append(f"[{timestamp}] {message}")