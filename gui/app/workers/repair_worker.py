"""后台修复线程"""

from PyQt6.QtCore import QThread, pyqtSignal


class RepairWorker(QThread):
    finished = pyqtSignal(dict)
    error = pyqtSignal(str)

    def __init__(self, api_client, input_path, output_path, params):
        super().__init__()
        self.api_client = api_client
        self.input_path = input_path
        self.output_path = output_path
        self.params = params

    def run(self):
        try:
            result = self.api_client.repair(
                self.input_path, self.output_path,
                params=self.params,
            )
            if result.get("ok"):
                self.finished.emit(result)
            else:
                self.error.emit(result.get("error", "未知错误"))
        except Exception as e:
            self.error.emit(str(e))