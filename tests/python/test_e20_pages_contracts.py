"""E20.6 contracts: Revisar, Exportar and Configurações join the Ameno shell."""

from __future__ import annotations

import os
import sys
import tempfile
from contextlib import contextmanager
from pathlib import Path
from unittest.mock import patch

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "Contents" / "python"))

from PySide6 import QtCore, QtWidgets  # noqa: E402

from ameno_ui.models import AuditSnapshot  # noqa: E402
from ameno_ui.window import AmenoMainWindow  # noqa: E402


PAGES = (
    ("create", "Cotar"),
    ("styles", "Estilos"),
    ("edit", "Revisar"),
    ("render", "Exportar"),
    ("config", "Configurações"),
)
AUDIT = AuditSnapshot("dim-01", "measured", 3500.0, 3500.0, 0.0, "3500 mm", "3500 mm", "0 mm",
                      "", False, "world", "Pontos no mundo", False, "")
GEOMETRIES = ((780, 1020), (780, 720), (980, 720), (1280, 800), (780, 560), (440, 1020))


class LocalBridge:
    def __init__(self) -> None:
        self.calls: list[str] = []

    def cancel_interactive(self):
        self.calls.append("cancel")
        return True


@contextmanager
def _window(width: int = 780, height: int = 1020):
    app = QtWidgets.QApplication.instance() or QtWidgets.QApplication([])
    bridge = LocalBridge()
    with tempfile.TemporaryDirectory(prefix="ameno-e20-pages-") as directory:
        with patch.dict(os.environ, {"AMENO_SETTINGS_FILE": str(Path(directory) / "settings.ini")}):
            window = AmenoMainWindow(bridge, lambda _token: None, lambda: None)
            window.show_application("create")
            window._frame_checked = True
            window.resize(width, height)
            window.show()
            for _ in range(3):
                app.processEvents()
            try:
                yield app, window, bridge
            finally:
                window.close()
                app.sendPostedEvents(None, QtCore.QEvent.Type.DeferredDelete)
                app.processEvents()


def _settle(app) -> None:
    for _ in range(3):
        app.processEvents()


def test_every_page_header_uses_its_navigation_name() -> None:
    with _window() as (_app, window, _bridge):
        for key, label in PAGES:
            page = window.shell.pages[key]
            assert page.findChild(QtWidgets.QLabel, "PageTitle").text() == label, key
            assert page.findChild(QtWidgets.QLabel, "Eyebrow").text() == label.upper(), key


def test_secondary_menus_share_one_label() -> None:
    with _window() as (_app, window, _bridge):
        for key in ("create", "edit", "render"):
            assert window.shell.pages[key].more_button.text() == "Mais ações", key


def test_pages_do_not_open_with_repeated_instructions() -> None:
    with _window() as (_app, window, _bridge):
        for key in ("edit", "render", "config"):
            page = window.shell.pages[key]
            assert page.status.isHidden(), key
        render = window.shell.pages["render"]
        assert render.findChild(QtWidgets.QGroupBox).title() != "Pronto para exportar"


def test_review_empty_state_is_compact_and_the_loaded_state_is_complete() -> None:
    with _window() as (app, window, _bridge):
        window.shell.show_page("edit")
        _settle(app)
        page = window.shell.pages["edit"]
        assert page.selection_stack.currentIndex() == 0
        assert page.selection_stack.height() <= 200
        page._load(AUDIT)
        _settle(app)
        assert page.selection_stack.currentIndex() == 1
        view = window.shell.page_views["edit"]
        view.ensureWidgetVisible(page.apply_button)
        _settle(app)
        top_left = page.apply_button.mapTo(view.viewport(), QtCore.QPoint(0, 0))
        assert view.viewport().rect().contains(QtCore.QRect(top_left, page.apply_button.size()))


def test_status_pill_and_secondary_buttons_keep_their_natural_width() -> None:
    with _window() as (app, window, _bridge):
        for key in ("render", "config"):
            window.shell.show_page(key)
            _settle(app)
        render = window.shell.pages["render"]
        assert render.renderer_state.width() <= render.renderer_state.sizeHint().width() + 8
        config = window.shell.pages["config"]
        for widget in (config.logout_button, config.copy_button):
            assert widget.width() <= widget.sizeHint().width() + 40, widget.text()


def test_primary_actions_stack_when_narrow() -> None:
    with _window(440, 1020) as (app, window, _bridge):
        window.shell.pages["edit"]._load(AUDIT)
        for key in ("edit", "render"):
            window.shell.show_page(key)
            _settle(app)
            page = window.shell.pages[key]
            primary = page.apply_button if key == "edit" else page.render_button
            start = primary.mapTo(page, QtCore.QPoint(0, 0))
            more = page.more_button.mapTo(page, QtCore.QPoint(0, 0))
            assert more.y() >= start.y() + primary.height(), key


def test_no_overflow_or_squeezed_button_in_any_geometry_and_no_scene_access() -> None:
    with _window() as (app, window, bridge):
        window.shell.pages["edit"]._load(AUDIT)
        for width, height in GEOMETRIES:
            window.resize(width, height)
            for key in ("edit", "render", "config"):
                window.shell.show_page(key)
                _settle(app)
                label = "%s %dx%d" % (key, width, height)
                view = window.shell.page_views[key]
                assert view.horizontalScrollBar().maximum() == 0, label
                page = window.shell.pages[key]
                for widget in page.findChildren(QtWidgets.QAbstractButton):
                    if widget.isVisibleTo(page) and widget.text():
                        assert widget.width() >= widget.minimumSizeHint().width(), (label, widget.text())
                for text_label in page.findChildren(QtWidgets.QLabel):
                    if text_label.isVisibleTo(page) and text_label.text() and not text_label.wordWrap():
                        needed = text_label.fontMetrics().horizontalAdvance(text_label.text())
                        assert text_label.contentsRect().width() >= needed, (label, text_label.text())
                for field in page.findChildren(QtWidgets.QLineEdit):
                    if field.isVisibleTo(page) and field.placeholderText() and not field.text():
                        needed = field.fontMetrics().horizontalAdvance(field.placeholderText())
                        assert field.width() - 20 >= needed, (label, field.placeholderText())
        assert bridge.calls == []
