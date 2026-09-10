"""E18.4 contracts for the clearer Appearance workflow."""

from __future__ import annotations

import os
import sys
from pathlib import Path

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "Contents" / "python"))

from PySide6 import QtWidgets  # noqa: E402

from ameno_ui.models import StyleSnapshot  # noqa: E402
from ameno_ui.styles_page import StylesPage  # noqa: E402


def _app() -> QtWidgets.QApplication:
    return QtWidgets.QApplication.instance() or QtWidgets.QApplication([])


class AppearanceBridge:
    def __init__(self) -> None:
        self.calls = []

    def styles(self):
        self.calls.append("styles")
        return []


def test_appearance_uses_one_vertical_flow_without_fixed_splitter() -> None:
    _app()
    page = StylesPage(AppearanceBridge())
    assert page.findChildren(QtWidgets.QSplitter) == []
    assert page.style_card is not None
    assert page.preview_box is not None
    assert page.text_box is not None
    assert page.advanced is not None


def test_empty_library_still_has_editable_default_draft_and_preview() -> None:
    _app()
    bridge = AppearanceBridge()
    page = StylesPage(bridge)
    page.load_styles([])
    assert page.draft.to_snapshot().style_id == "default"
    assert page.preview._style.style_id == "default"
    bridge.calls.clear()
    page.font_size.setValue(210)
    assert page.draft.value("font_size") == 210.0
    assert page.draft.dirty
    assert bridge.calls == []


def test_loading_a_style_updates_draft_and_keeps_actions_explicit() -> None:
    _app()
    page = StylesPage(AppearanceBridge())
    page.load_styles([StyleSnapshot("s", "Editorial", font_size=220, terminal_type="dot")])
    assert page.draft.to_snapshot().style_id == "s"
    assert page.draft.value("font_size") == 220.0
    assert page.draft.value("terminal_type") == "dot"
    assert page.save_button.property("primary") in (None, False)
    assert page.apply_button.property("primary") is True


def test_appearance_fits_narrow_page_without_horizontal_content() -> None:
    app = _app()
    page = StylesPage(AppearanceBridge())
    page.resize(580, 560)
    page.show()
    app.processEvents()
    assert page.minimumSizeHint().width() <= page.width()
    for widget in page.findChildren(QtWidgets.QWidget):
        if widget.isVisible() and widget.parentWidget() is not None:
            parent = widget.parentWidget()
            assert widget.geometry().right() <= parent.rect().right(), widget.objectName()
    page.close()
    app.processEvents()
