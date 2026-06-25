"""后台媒体探测线程"""

import requests
from PyQt6.QtCore import QThread, pyqtSignal


class ProbeWorker(QThread):
    finished = pyqtSignal(dict)
    error = pyqtSignal(str)

    def __init__(self, api_client, file_path):
        super().__init__()
        self.api_client = api_client
        self.file_path = file_path

    def run(self):
        try:
            # 用 ffprobe 端点探测（如果后端有的话）
            # 暂时返回基本信息
            import os
            info = {
                "file_path": self.file_path,
                "file_size": os.path.getsize(self.file_path),
                "format_name": os.path.splitext(self.file_path)[1].replace(".", ""),
            }
            self.finished.emit(info)
        except Exception as e:
            self.error.emit(str(e))