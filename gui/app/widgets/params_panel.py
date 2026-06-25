"""动态参数面板 — 根据 /api/algorithms 生成"""

from PyQt6.QtWidgets import (
    QWidget, QFormLayout, QDoubleSpinBox, QComboBox, QLabel,
)


class ParamsPanel(QWidget):
    def __init__(self):
        super().__init__()
        self.layout = QFormLayout(self)
        self.layout.setSpacing(8)
        self.widgets = {}
        self.algorithms = []

        placeholder = QLabel("请先连接服务...")
        self.layout.addRow(placeholder)

    def set_algorithms(self, algorithms):
        # 清空
        while self.layout.count():
            item = self.layout.takeAt(0)
            if item.widget():
                item.widget().deleteLater()
        self.widgets = {}
        self.algorithms = algorithms

        if not algorithms:
            self.layout.addRow(QLabel("无可用算法"))
            return

        # 取第一个 repair 算法
        repair_algo = None
        for algo in algorithms:
            if algo.get("mode") == "repair":
                repair_algo = algo
                break

        if not repair_algo:
            self.layout.addRow(QLabel("无 repair 算法"))
            return

        self.layout.addRow(QLabel(f"算法: {repair_algo.get('name', '')}"))

        for param in repair_algo.get("params", []):
            name = param["name"]
            label = param.get("label", name)
            ptype = param.get("type", "Float64")
            default = param.get("default", 0)
            pmin = param.get("min", 0)
            pmax = param.get("max", 100)
            step = param.get("step", 1)

            if ptype == "Float64":
                spin = QDoubleSpinBox()
                spin.setRange(float(pmin), float(pmax))
                spin.setValue(float(default))
                spin.setSingleStep(float(step))
                spin.setDecimals(2)
                self.layout.addRow(label, spin)
                self.widgets[name] = spin
            elif ptype == "Int":
                from PyQt6.QtWidgets import QSpinBox
                spin = QSpinBox()
                spin.setRange(int(pmin), int(pmax))
                spin.setValue(int(default))
                self.layout.addRow(label, spin)
                self.widgets[name] = spin
            elif ptype == "String" and param.get("choices"):
                combo = QComboBox()
                combo.addItems(param["choices"])
                combo.setCurrentText(str(default))
                self.layout.addRow(label, combo)
                self.widgets[name] = combo

    def get_params(self) -> dict:
        params = {}
        for name, widget in self.widgets.items():
            if hasattr(widget, 'value'):
                params[name] = widget.value()
            elif hasattr(widget, 'currentText'):
                params[name] = widget.currentText()
        return params