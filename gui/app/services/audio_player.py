"""音频播放"""

import subprocess
import sys
import os


class AudioPlayer:
    def play(self, file_path: str):
        if not os.path.exists(file_path):
            return

        if sys.platform == "win32":
            subprocess.Popen(["start", file_path], shell=True)
        elif sys.platform == "darwin":
            subprocess.Popen(["afplay", file_path])
        else:
            subprocess.Popen(["xdg-open", file_path])