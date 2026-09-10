"""E18.2 contracts for slider + precise numeric controls."""

from __future__ import annotations

import os
import sys
from pathlib import Path

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "Contents" / "python"))

from PySide6 import QtCore, QtWidgets  # noqa: E402

from ameno_ui.parameter_control import ParameterControl, ParameterSpec  # noqa: E402


def _app() -> QtWidgets.QApplication:
    return QtWidgets.QApplication.instance() or QtWidgets.QApplication([])


def _spec() -> ParameterSpec:
    return ParameterSpec("gap", "Distância", 0, 250, 0, 1000, 1, 60, "mm", 1, "Teste")


def test_slider_and_spinbox_are_synchronized_with_one_signal() -> None:
    _app()
    control = ParameterControl(_spec())
    values = []
    control.value_changed.connect(values.append)
    control.slider.setValue(control.slider.value() + 10)
    assert control.value() == 70.0
    assert values == [70.0]
    values.clear()
    control.spinbox.setValue(123.0)
    assert control.slider.value() == 123
    assert values == [123.0]


def test_technical_input_can_exceed_slider_range_but_stays_bounded() -> None:
    _app()
    control = ParameterControl(_spec())
    control.setValue(800)
    assert control.value() == 800.0
    assert control.slider.value() == control.slider.maximum()
    control.setValue(9999)
    assert control.value() == 1000.0
    control.setValue("-10")
    assert control.value() == 0.0


def test_decimal_comma_keyboard_and_reset_are_local() -> None:
    _app()
    control = ParameterControl(
        ParameterSpec("thickness", "Espessura", 0.2, 10, 0.1, 100, 0.1, 1.5, "mm", 1)
    )
    events = []
    control.value_changed.connect(events.append)
    control.spinbox.lineEdit().setText("2,7")
    control.spinbox.interpretText()
    assert control.value() == 2.7
    control.reset()
    assert control.value() == 1.5
    assert events == [2.7, 1.5]


def test_control_has_focusable_accessible_children_and_no_timer() -> None:
    _app()
    control = ParameterControl(_spec())
    assert control.accessibleName() == "Distância"
    assert control.slider.accessibleName()
    assert control.spinbox.accessibleName()
    assert control.reset_button.accessibleName()
    assert control.findChildren(QtCore.QTimer) == []
