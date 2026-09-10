"""E18 red tests: capture the two human-reported E17 usability failures."""

from __future__ import annotations

import os
import sys
from pathlib import Path

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "Contents" / "python"))

from PySide6 import QtCore, QtGui, QtWidgets  # noqa: E402

from ameno_ui.models import CreateSnapshot, SceneSnapshot, StyleSnapshot  # noqa: E402
from ameno_ui.styles_page import StylesPage  # noqa: E402
from ameno_ui.window import AmenoMainWindow  # noqa: E402


def _app() -> QtWidgets.QApplication:
    return QtWidgets.QApplication.instance() or QtWidgets.QApplication([])


class BaselineBridge:
    """Constructor-only bridge: these tests must not need a Max scene."""

    def __init__(self) -> None:
        self.calls = []

    def scene(self):
        self.calls.append("scene")
        return SceneSnapshot(status="ready", status_label="Pronta")

    def styles(self):
        self.calls.append("styles")
        return [StyleSnapshot("default", "Arquitetônico")]

    def create(self):
        self.calls.append("create")
        return CreateSnapshot()

    def cancel_interactive(self):
        self.calls.append("cancel")
        return True


def _png_bytes(widget: QtWidgets.QWidget) -> bytes:
    image = QtGui.QImage(widget.size(), QtGui.QImage.Format.Format_ARGB32)
    image.fill(QtCore.Qt.GlobalColor.transparent)
    widget.render(image)
    buffer = QtCore.QBuffer()
    buffer.open(QtCore.QIODevice.OpenModeFlag.WriteOnly)
    assert image.save(buffer, "PNG")
    return bytes(buffer.data())


def test_preview_reacts_before_style_list_refresh() -> None:
    """Changing a field before Refresh must change the local preview."""

    _app()
    page = StylesPage(BaselineBridge())
    assert page.preview._style is not None, "Aparência deve nascer com um draft padrão"
    page.preview.resize(620, 240)
    page.preview.show()
    before = _png_bytes(page.preview)

    page.font_size.setValue(page.font_size.value() + 80.0)
    QtWidgets.QApplication.processEvents()
    after = _png_bytes(page.preview)

    assert before != after, "a prévia continua no snapshot padrão após editar o campo"


def test_pages_fit_default_window_without_horizontal_scroll() -> None:
    """The real default-sized shell must keep every page horizontally usable."""

    app = _app()
    window = AmenoMainWindow(BaselineBridge(), lambda _token: None, lambda: None)
    window.show_application("styles")
    window.show()
    app.processEvents()

    for width, height in ((780, 560), (980, 720)):
        window.resize(width, height)
        for key, view in window.shell.page_views.items():
            window.shell.show_page(key)
            app.processEvents()
            assert view.horizontalScrollBar().maximum() == 0, (
                "a página %s exige rolagem horizontal em %sx%s"
                % (key, width, height)
            )

    window.close()
    app.processEvents()
