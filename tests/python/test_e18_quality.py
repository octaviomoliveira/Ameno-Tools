"""E18.9 accessibility, local-performance and lifecycle contracts."""

from __future__ import annotations

import os
import sys
import time
from pathlib import Path

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "Contents" / "python"))

from PySide6 import QtCore, QtWidgets  # noqa: E402

from ameno_ui.parameter_control import ParameterControl, ParameterSpec  # noqa: E402
from ameno_ui.styles_page import StylesPage  # noqa: E402
from ameno_ui.window import AmenoMainWindow  # noqa: E402


def _app() -> QtWidgets.QApplication:
    return QtWidgets.QApplication.instance() or QtWidgets.QApplication([])


class QualityBridge:
    def __init__(self) -> None:
        self.calls = []

    def cancel_interactive(self):
        self.calls.append("cancel")
        return True


def test_visible_actions_have_accessible_names() -> None:
    _app()
    window = AmenoMainWindow(QualityBridge(), lambda _token: None, lambda: None)
    window.show_application("create")
    window.show()
    QtWidgets.QApplication.processEvents()
    for widget in window.findChildren(QtWidgets.QAbstractButton):
        if widget.isVisible():
            assert widget.accessibleName(), widget.text()
    window.close()


def test_parameter_wheel_is_ignored_without_focus() -> None:
    _app()
    control = ParameterControl(ParameterSpec("x", "X", 0, 10, 0, 20, 1, 5))
    wheel = QtCore.QEvent(QtCore.QEvent.Type.Wheel)
    assert control.eventFilter(control.spinbox, wheel) is True


def test_local_preview_update_p95_stays_under_20ms_without_bridge() -> None:
    _app()
    bridge = QualityBridge()
    page = StylesPage(bridge)
    durations = []
    for index in range(1000):
        start = time.perf_counter()
        page.font_size.setValue(10 + (index % 490))
        QtWidgets.QApplication.processEvents()
        durations.append(time.perf_counter() - start)
    ordered = sorted(durations)
    p95 = ordered[int(len(ordered) * 0.95) - 1]
    assert p95 < 0.020, p95
    assert bridge.calls == []
    assert page.findChildren(QtCore.QTimer) == []


def test_resize_navigation_lifecycle_keeps_widget_tree_and_connections_stable() -> None:
    app = _app()
    bridge = QualityBridge()
    window = AmenoMainWindow(bridge, lambda _token: None, lambda: None)
    window.show_application("create")
    window.show()
    app.processEvents()
    count = len(window.findChildren(QtWidgets.QWidget))
    pages = {key: id(page) for key, page in window.shell.pages.items()}
    for index in range(100):
        window.resize(780 + (index % 5) * 100, 560 + (index % 4) * 60)
        window.shell.show_page(("create", "styles", "edit", "render", "config")[index % 5])
        app.processEvents()
    assert len(window.findChildren(QtWidgets.QWidget)) == count
    assert {key: id(page) for key, page in window.shell.pages.items()} == pages
    assert window.findChildren(QtCore.QTimer) == []
    assert bridge.calls == []
    window.close()
