"""文件管理"""

import os


class FileManager:
    def __init__(self, output_dir: str = None):
        if output_dir is None:
            output_dir = os.path.join(
                os.path.dirname(os.path.dirname(os.path.dirname(__file__))),
                "..", "output",
            )
        self.output_dir = os.path.abspath(output_dir)

    def ensure_output_dir(self):
        os.makedirs(self.output_dir, exist_ok=True)

    def get_output_dir(self) -> str:
        return self.output_dir

    def get_output_path(self, filename: str) -> str:
        return os.path.join(self.output_dir, filename)