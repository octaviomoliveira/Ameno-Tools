"""Reusable slider + precise numeric editor for local style parameters."""

from __future__ import annotations

from dataclasses import dataclass
from math import isfinite
from typing import Any

from .qt_compat import QtCore, QtWidgets


@dataclass(frozen=True)
class ParameterSpec:
    field_name: str
    label: str
    slider_min: float
    slider_max: float
    input_min: float
    input_max: float
    step: float
    default: float
    unit: str = ""
    decimals: int = 1
    description: str = ""


class ParameterControl(QtWidgets.QWidget):
    """A bounded, keyboard-accessible slider and numeric input pair.

    The slider covers a comfortable exploration range while the spin box keeps
    the wider technical range. Both controls are local and emit one semantic
    value signal per completed source change.
    """

    value_changed = QtCore.Signal(float)
    valueChanged = value_changed

    def __init__(self, spec: ParameterSpec, parent=None) -> None:
        super().__init__(parent)
        self.spec = spec
        self.setObjectName("ParameterControl")
        self.setAccessibleName(spec.label)
        if spec.description:
            self.setToolTip(spec.description)

        layout = QtWidgets.QHBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(8)

        self.slider = QtWidgets.QSlider(QtCore.Qt.Orientation.Horizontal)
        self.slider.setObjectName("ParameterSlider")
        self.slider.setAccessibleName(spec.label + " (explorar)")
        self._slider_steps = max(1, int(round((spec.slider_max - spec.slider_min) / spec.step)))
        self.slider.setRange(0, self._slider_steps)
        self.slider.setTracking(True)
        layout.addWidget(self.slider, 1)

        self.spinbox = QtWidgets.QDoubleSpinBox()
        self.spinbox.setObjectName("ParameterValue")
        self.spinbox.setRange(spec.input_min, spec.input_max)
        self.spinbox.setDecimals(spec.decimals)
        self.spinbox.setSingleStep(spec.step)
        self.spinbox.setKeyboardTracking(True)
        self.spinbox.setSuffix((" " + spec.unit) if spec.unit else "")
        self.spinbox.setAccessibleName(spec.label + ((" (" + spec.unit + ")") if spec.unit else ""))
        self.spinbox.setToolTip(spec.description or spec.label)
        self.spinbox.installEventFilter(self)
        layout.addWidget(self.spinbox)

        self.reset_button = QtWidgets.QToolButton()
        self.reset_button.setText("↺")
        self.reset_button.setToolTip("Restaurar padrão: %s" % self._format(spec.default))
        self.reset_button.setAccessibleName("Restaurar " + spec.label)
        self.reset_button.setAutoRaise(True)
        layout.addWidget(self.reset_button)

        self.slider.valueChanged.connect(self._slider_changed)
        self.spinbox.valueChanged.connect(self._spin_changed)
        self.reset_button.clicked.connect(lambda: self.setValue(spec.default))
        self.setValue(spec.default, emit=False)

    def _format(self, value: float) -> str:
        return ("%.*f" % (self.spec.decimals, value)).rstrip("0").rstrip(".")

    def _clamp_input(self, value: Any) -> float:
        try:
            number = float(str(value).strip().replace(",", "."))
        except (TypeError, ValueError):
            number = self.spec.default
        if not isfinite(number):
            number = self.spec.default
        return max(self.spec.input_min, min(self.spec.input_max, number))

    def _slider_value(self, value: float) -> int:
        if value <= self.spec.slider_min:
            return 0
        if value >= self.spec.slider_max:
            return self._slider_steps
        return int(round((value - self.spec.slider_min) / self.spec.step))

    def _value_from_slider(self, value: int) -> float:
        number = self.spec.slider_min + value * self.spec.step
        return round(number, self.spec.decimals + 2)

    def _set_value(self, value: Any, emit: bool) -> None:
        number = self._clamp_input(value)
        blockers = (QtCore.QSignalBlocker(self.slider), QtCore.QSignalBlocker(self.spinbox))
        self.slider.setValue(self._slider_value(number))
        self.spinbox.setValue(number)
        del blockers
        if emit:
            self.value_changed.emit(float(self.spinbox.value()))

    def _slider_changed(self, value: int) -> None:
        self._set_value(self._value_from_slider(value), emit=True)

    def _spin_changed(self, value: float) -> None:
        self._set_value(value, emit=True)

    def eventFilter(self, watched, event) -> bool:  # noqa: N802 - Qt API
        if (
            watched is self.spinbox
            and event.type() == QtCore.QEvent.Type.Wheel
            and not self.spinbox.hasFocus()
        ):
            return True
        return super().eventFilter(watched, event)

    def value(self) -> float:
        return float(self.spinbox.value())

    def setValue(self, value: Any, emit: bool = True) -> None:  # noqa: N802 - Qt-like API
        self._set_value(value, emit=emit)

    def set_value(self, value: Any, emit: bool = True) -> None:
        self.setValue(value, emit=emit)

    def reset(self) -> None:
        self.setValue(self.spec.default)


def style_parameter_specs() -> tuple[ParameterSpec, ...]:
    return (
        ParameterSpec("font_size", "Tamanho", 10, 500, 1, 5000, 1, 140, "mm", 1, "Tamanho do texto da cota."),
        ParameterSpec("tracking", "Espaçamento", -10, 50, -100, 100, 0.5, 0, "", 1, "Distância relativa entre caracteres."),
        ParameterSpec("text_gap", "Distância da linha", 0, 250, 0, 1000, 1, 60, "mm", 1, "Afastamento do texto em relação à linha."),
        ParameterSpec("line_thickness", "Espessura", 0.2, 10, 0.1, 100, 0.1, 1.5, "mm", 1, "Espessura da linha da cota."),
        ParameterSpec("extension_overhang", "Prolongamento", 0, 300, 0, 2000, 1, 80, "mm", 1, "Quanto a extensão passa do ponto."),
        ParameterSpec("extension_gap", "Recuo", 0, 200, 0, 2000, 1, 0, "mm", 1, "Espaço entre o ponto e a extensão."),
        ParameterSpec("terminal_size", "Tamanho", 10, 300, 0, 2000, 1, 100, "mm", 1, "Tamanho do terminal."),
        ParameterSpec("terminal_angle", "Ângulo", 0, 180, 0, 180, 1, 45, "°", 1, "Rotação do terminal."),
    )
