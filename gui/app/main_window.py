"""主窗口"""

import os
from PyQt6.QtWidgets import (
    QMainWindow, QWidget, QVBoxLayout, QHBoxLayout,
    QPushButton, QLabel, QMessageBox,
    QProgressBar, QGroupBox, QSplitter,
)
from PyQt6.QtCore import Qt

from app.services.api_client import APIClient
from app.services.file_manager import FileManager
from app.services.audio_player import AudioPlayer
from app.workers.repair_worker import RepairWorker
from app.workers.probe_worker import ProbeWorker
from app.widgets.drop_area import DropArea
from app.widgets.params_panel import ParamsPanel
from app.widgets.result_panel import ResultPanel
from app.widgets.log_panel import LogPanel


class MainWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("AIVoiceSeamFix — AI 配音断裂修复工具")
        self.setMinimumSize(700, 600)

        self.api_client = APIClient()
        self.file_manager = FileManager()
        self.audio_player = AudioPlayer()
        self.input_path = None
        self.output_path = None
        self.output_dir = self.file_manager.get_output_dir()

        self._setup_ui()
        self._check_server()

    def _setup_ui(self):
        central = QWidget()
        self.setCentralWidget(central)
        layout = QVBoxLayout(central)
        layout.setSpacing(12)

        # 上半部分：拖拽 + 参数
        top_splitter = QSplitter(Qt.Orientation.Vertical)

        # 拖拽区
        self.drop_area = DropArea()
        self.drop_area.file_dropped.connect(self._on_file_selected)
        top_splitter.addWidget(self.drop_area)

        # 参数面板
        params_group = QGroupBox("修复参数")
        params_layout = QVBoxLayout(params_group)
        self.params_panel = ParamsPanel()
        params_layout.addWidget(self.params_panel)
        top_splitter.addWidget(params_group)

        layout.addWidget(top_splitter)

        # 进度条
        self.progress = QProgressBar()
        self.progress.setVisible(False)
        layout.addWidget(self.progress)

        # 按钮行
        btn_layout = QHBoxLayout()

        self.btn_repair = QPushButton("🔧 开始修复")
        self.btn_repair.setEnabled(False)
        self.btn_repair.clicked.connect(self._on_repair)
        btn_layout.addWidget(self.btn_repair)

        self.btn_refresh = QPushButton("🔄 刷新算法")
        self.btn_refresh.clicked.connect(self._load_algorithms)
        btn_layout.addWidget(self.btn_refresh)

        self.btn_play_original = QPushButton("▶ 播放原音")
        self.btn_play_original.setEnabled(False)
        self.btn_play_original.clicked.connect(self._play_original)
        btn_layout.addWidget(self.btn_play_original)

        self.btn_play_fixed = QPushButton("▶ 播放修复")
        self.btn_play_fixed.setEnabled(False)
        self.btn_play_fixed.clicked.connect(self._play_fixed)
        btn_layout.addWidget(self.btn_play_fixed)

        layout.addLayout(btn_layout)

        # 下半部分：结果 + 日志
        bottom_splitter = QSplitter(Qt.Orientation.Vertical)

        self.result_panel = ResultPanel()
        bottom_splitter.addWidget(self.result_panel)

        self.log_panel = LogPanel()
        bottom_splitter.addWidget(self.log_panel)

        layout.addWidget(bottom_splitter)

        # 状态栏
        self.status_label = QLabel("就绪")
        layout.addWidget(self.status_label)

    def _log(self, message):
        self.log_panel.add_message(message)

    def _check_server(self):
        if self.api_client.check_status():
            self.status_label.setText("✅ 服务已连接")
            self._log("服务已连接")
            self._load_algorithms()
        else:
            self.status_label.setText("⚠️ 服务未连接，请先启动 Julia 后端")
            self._log("⚠️ 服务未连接")

    def _load_algorithms(self):
        try:
            algorithms = self.api_client.get_algorithms()
            self.params_panel.set_algorithms(algorithms)
            self.status_label.setText(f"✅ 服务已连接 — {len(algorithms)} 个算法可用")
            self._log(f"加载 {len(algorithms)} 个算法")
        except Exception as e:
            self.status_label.setText(f"❌ 加载算法失败: {e}")
            self._log(f"❌ 加载算法失败: {e}")

    def _on_file_selected(self, file_path):
        self.input_path = file_path
        self.drop_area.set_file_name(os.path.basename(file_path))
        self.btn_repair.setEnabled(True)
        self.btn_play_original.setEnabled(True)
        self.status_label.setText(f"已选择: {os.path.basename(file_path)}")

        # 后台探测媒体信息
        self.probe_worker = ProbeWorker(self.api_client, file_path)
        self.probe_worker.finished.connect(self._on_probe_finished)
        self.probe_worker.error.connect(lambda e: self._log(f"⚠️ 探测失败: {e}"))
        self.probe_worker.start()

    def _on_probe_finished(self, info):
        self.result_panel.show_file_info(info)
        self._log(f"文件信息: {info.get('duration_sec', 0):.1f}s, "
                  f"{info.get('sample_rate', 0)}Hz, "
                  f"{info.get('channels', 0)}ch")

    def _on_repair(self):
        if not self.input_path:
            return

        self.file_manager.ensure_output_dir()
        base = os.path.splitext(os.path.basename(self.input_path))[0]
        self.output_path = self.file_manager.get_output_path(f"{base}_fixed.wav")

        params = self.params_panel.get_params()

        self.progress.setVisible(True)
        self.progress.setRange(0, 0)
        self.btn_repair.setEnabled(False)
        self._log(f"开始修复: {os.path.basename(self.input_path)}")
        self._log(f"参数: {params}")

        self.worker = RepairWorker(
            self.api_client, self.input_path, self.output_path, params,
        )
        self.worker.finished.connect(self._on_finished)
        self.worker.error.connect(self._on_error)
        self.worker.start()

    def _on_finished(self, result):
        self.progress.setVisible(False)
        self.btn_repair.setEnabled(True)
        self.btn_play_fixed.setEnabled(True)

        detected = result.get("detected_regions", 0)
        self.status_label.setText(f"✅ 修复完成 — 检测到 {detected} 个断裂区域")
        self.result_panel.show_result(result)
        self._log(f"✅ 修复完成: {detected} 个断裂区域")

    def _on_error(self, error_msg):
        self.progress.setVisible(False)
        self.btn_repair.setEnabled(True)
        self.status_label.setText(f"❌ 修复失败: {error_msg}")
        self._log(f"❌ 修复失败: {error_msg}")

    def _play_original(self):
        if self.input_path:
            self.audio_player.play(self.input_path)
            self._log(f"▶ 播放原音: {os.path.basename(self.input_path)}")

    def _play_fixed(self):
        if self.output_path and os.path.exists(self.output_path):
            self.audio_player.play(self.output_path)
            self._log(f"▶ 播放修复: {os.path.basename(self.output_path)}")