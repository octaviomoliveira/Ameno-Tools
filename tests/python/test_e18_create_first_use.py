"""E18.6 first-use contracts for Cotar."""

from __future__ import annotations

import os
import sys
import tempfile
from pathlib import Path

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "Contents" / "python"))

from PySide6 import QtCore, QtWidgets  # noqa: E402

from ameno_ui.create_page import CreatePage  # noqa: E402
from ameno_ui.models import StyleSnapshot  # noqa: E402
from ameno_ui.window import AmenoMainWindow  # noqa: E402


def _app() -> QtWidgets.QApplication:
    return QtWidgets.QApplication.instance() or QtWidgets.QApplication([])


class CreateBridge:
    def __init__(self) -> None:
        self.calls = []

    def cancel_interactive(self):
        self.calls.append("cancel")
        return True


def test_first_use_has_one_cta_and_summary_follows_choices() -> None:
    _app()
    os.environ["AMENO_SETTINGS_FILE"] = str(Path(tempfile.mkdtemp()) / "first-use.ini")
    page = CreatePage(CreateBridge())
    assert page.start_button.property("primary") is True
    assert sum(
        1
        for widget in page.findChildren(QtWidgets.QPushButton)
        if widget.property("primary")
    ) == 1
    assert "planta" in page.selection_summary.text().lower()
    page.plane_choice.set_value("viewPlane", emit=True)
    page.tool_choice.set_value("continuous", emit=True)
    assert "fachada/vista" in page.selection_summary.text().lower()
    assert "várias medidas" in page.selection_summary.text().lower()


def test_cta_is_visible_in_default_window_without_scrolling() -> None:
    app = _app()
    os.environ["AMENO_SETTINGS_FILE"] = str(Path(tempfile.mkdtemp()) / "cta-window.ini")
    window = AmenoMainWindow(CreateBridge(), lambda _token: None, lambda: None)
    window.resize(980, 720)
    window.show_application("create")
    window.show()
    app.processEvents()
    view = window.shell.page_views["create"]
    start = window.shell.pages["create"].start_button
    top_left = start.mapTo(view.viewport(), QtCore.QPoint(0, 0))
    assert top_left.y() >= 0
    assert top_left.y() + start.height() <= view.viewport().height()
    window.close()
    app.processEvents()


def test_existing_style_choices_remain_available_after_guided_rewrite() -> None:
    _app()
    page = CreatePage(CreateBridge())
    page.load_styles([StyleSnapshot("s", "Editorial")])
    assert page.style.findData("s") >= 0
    assert page.start_button.text() == "Iniciar cotação"
