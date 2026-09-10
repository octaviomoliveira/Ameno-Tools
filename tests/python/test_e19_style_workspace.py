"""E19 contracts for the fixed-preview style workspace."""

from __future__ import annotations

import os
import sys
import tempfile
from pathlib import Path

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "Contents" / "python"))

from PySide6 import QtCore, QtGui, QtWidgets  # noqa: E402

from ameno_ui.components import CollapsibleSection, ColorControl  # noqa: E402
from ameno_ui.models import StyleSnapshot  # noqa: E402
from ameno_ui.window import AmenoMainWindow  # noqa: E402


class StyleBridge:
    def __init__(self) -> None:
        self.calls = []

    def cancel_interactive(self):
        return True


def _app() -> QtWidgets.QApplication:
    return QtWidgets.QApplication.instance() or QtWidgets.QApplication([])


def _pixels(widget: QtWidgets.QWidget) -> bytes:
    image = QtGui.QImage(widget.size(), QtGui.QImage.Format.Format_ARGB32)
    image.fill(QtCore.Qt.GlobalColor.transparent)
    widget.render(image)
    bits = image.bits()
    return bytes(bits[: image.sizeInBytes()])


def _window(width: int, height: int):
    os.environ["AMENO_SETTINGS_FILE"] = str(Path(tempfile.mkdtemp()) / "e19-style.ini")
    window = AmenoMainWindow(StyleBridge(), lambda _token: None, lambda: None)
    window.resize(width, height)
    window.show_application("styles")
    window.show()
    _app().processEvents()
    return window


def test_window_opens_in_comfortable_horizontal_workspace() -> None:
    app = _app()
    window = AmenoMainWindow(StyleBridge(), lambda _token: None, lambda: None)
    available = (window.screen() or QtGui.QGuiApplication.primaryScreen()).availableGeometry().size()
    assert window.width() == max(780, min(1280, available.width() - 24))
    assert window.height() == max(560, min(720, available.height() - 24))
    window.close()
    app.processEvents()


def test_style_workspace_keeps_preview_and_footer_fixed_at_980x720() -> None:
    app = _app()
    window = _window(980, 720)
    page = window.shell.pages["styles"]
    view = window.shell.page_views["styles"]
    assert page._workspace_mode == "wide"
    assert page.preview_box.parentWidget() is page.editor
    assert not page.controls_scroll.isAncestorOf(page.preview_box)
    # Keep enough room for Max's real font metrics: earlier proportional
    # splits left 323-389 px and still truncated numeric inputs in the host.
    assert page.controls_scroll.viewport().width() >= 440
    assert page.name.width() >= 265
    assert page.preview_box.width() >= 250
    assert view.verticalScrollBarPolicy() == QtCore.Qt.ScrollBarPolicy.ScrollBarAlwaysOff
    assert view.horizontalScrollBar().maximum() == 0
    footer_pos = page.footer.mapTo(view.viewport(), QtCore.QPoint(0, 0))
    assert footer_pos.y() >= 0
    assert footer_pos.y() + page.footer.height() <= view.viewport().height()
    assert page.apply_button.property("primary") is True
    assert page.save_button.property("primary") in (None, False)
    window.close()
    app.processEvents()


def test_style_workspace_uses_four_groups_and_separate_color_swatch() -> None:
    app = _app()
    window = _window(980, 720)
    page = window.shell.pages["styles"]
    sections = page.controls_scroll.widget().findChildren(CollapsibleSection)
    assert [section.toggle.text() for section in sections] == ["Texto", "Linhas", "Terminais", "Cores"]
    assert isinstance(page.annotation_color, ColorControl)
    page.annotation_color.set_color_text("239,68,68")
    assert page.annotation_color.value_label.text() == "#EF4444"
    assert not page.annotation_color.edit_button.styleSheet()
    for control in (page.font_size, page.tracking, page.text_gap):
        assert not control.reset_button.icon().isNull()
        assert control.spinbox.suffix().strip() == control.spec.unit
    window.close()
    app.processEvents()


def test_style_preview_changes_locally_and_never_enters_controls_scroll() -> None:
    app = _app()
    window = _window(980, 720)
    page = window.shell.pages["styles"]
    page.preview.resize(420, 280)
    app.processEvents()
    before = _pixels(page.preview)
    page.font_size.setValue(240)
    app.processEvents()
    after = _pixels(page.preview)
    assert before != after
    assert page.bridge.calls == []
    assert not page.controls_scroll.isAncestorOf(page.preview)
    window.close()
    app.processEvents()


def test_style_compact_mode_places_fixed_preview_above_scrolling_controls() -> None:
    app = _app()
    window = _window(780, 560)
    page = window.shell.pages["styles"]
    assert page._workspace_mode == "compact"
    assert page.workspace_layout.indexOf(page.preview_box) == 0
    assert page.workspace_layout.indexOf(page.controls_scroll) == 1
    assert page.preview_box.height() <= 230
    assert not page.controls_scroll.isAncestorOf(page.preview_box)
    view = window.shell.page_views["styles"]
    footer_pos = page.footer.mapTo(view.viewport(), QtCore.QPoint(0, 0))
    assert footer_pos.y() >= 0
    assert footer_pos.y() + page.footer.height() <= view.viewport().height()
    assert view.verticalScrollBar().maximum() == 0
    window.close()
    app.processEvents()
