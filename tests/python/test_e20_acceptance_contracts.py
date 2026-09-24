"""E20.7 acceptance matrix: overflow, keyboard, performance and lifecycle.

Runs the whole Qt surface offscreen with a bridge that records every call.
The MAXScript regression matrix needs 3ds Max and is not part of this file.
"""

from __future__ import annotations

import os
import sys
import tempfile
from contextlib import contextmanager
from pathlib import Path
from time import perf_counter
from unittest.mock import patch

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "Contents" / "python"))

from PySide6 import QtCore, QtTest, QtWidgets  # noqa: E402

from ameno_ui.components import ChoiceCard, CollapsibleSection, Disclosure  # noqa: E402
from ameno_ui.models import AuditSnapshot, CreateSnapshot, SceneSnapshot, StyleSnapshot  # noqa: E402
from ameno_ui.window import AmenoMainWindow  # noqa: E402


PAGES = ("create", "styles", "edit", "render", "config")
GEOMETRIES = ((780, 1020), (780, 720), (980, 720), (1280, 800), (780, 560), (440, 1020))
AUDIT = AuditSnapshot("dim-01", "manualText", 3500.0, 3500.0, 0.0, "3500 mm", "verificar", "—",
                      "medida de obra", True, "world", "Pontos no mundo", False, "")
STYLES = [StyleSnapshot("default", "Arquitetônico"), StyleSnapshot("technical", "Técnico")]


class RecordingBridge:
    def __init__(self) -> None:
        self.calls: list[str] = []

    def cancel_interactive(self):
        self.calls.append("cancel")
        return True

    def __getattr__(self, name):
        def call(*_args, **_kwargs):
            self.calls.append(name)
            raise AssertionError("unexpected scene access: " + name)
        return call


def _app() -> QtWidgets.QApplication:
    return QtWidgets.QApplication.instance() or QtWidgets.QApplication([])


def _settle(app) -> None:
    for _ in range(3):
        app.processEvents()


@contextmanager
def _window(width: int = 780, height: int = 1020, bridge=None):
    app = _app()
    bridge = bridge or RecordingBridge()
    with tempfile.TemporaryDirectory(prefix="ameno-e20-acceptance-") as directory:
        with patch.dict(os.environ, {"AMENO_SETTINGS_FILE": str(Path(directory) / "settings.ini")}):
            window = AmenoMainWindow(bridge, lambda _token: None, lambda: None)
            window.show_application("create")
            window._frame_checked = True
            window.resize(width, height)
            window.show()
            _settle(app)
            try:
                yield app, window, bridge
            finally:
                window.close()
                app.sendPostedEvents(None, QtCore.QEvent.Type.DeferredDelete)
                app.processEvents()


def _load_rich_state(window) -> None:
    """Fill every page with realistic, locally loaded content."""
    pages = window.shell.pages
    pages["create"].load_styles(STYLES)
    pages["create"].load_snapshot({
        "scene": SceneSnapshot("requiresRepair", "Requer reparo",
                               "A infraestrutura Ameno está incompleta e pode ser reparada.", 12),
        "create": CreateSnapshot(),
    })
    pages["create"].tool_choice.set_value("continuous", emit=True)
    pages["create"].details.toggle.setChecked(True)
    pages["styles"].load_styles(STYLES)
    for section in pages["styles"].findChildren(CollapsibleSection):
        section.toggle.setChecked(True)
    pages["edit"]._load(AUDIT)
    for disclosure in pages["config"].findChildren(Disclosure):
        disclosure.toggle.setChecked(True)


def _overflow_problems(page: QtWidgets.QWidget, label: str) -> list:
    problems = []

    def visible(widget) -> bool:
        return widget.isVisibleTo(page) and widget.width() > 0

    for widget in page.findChildren(QtWidgets.QAbstractButton):
        if visible(widget) and widget.text() and not isinstance(widget, ChoiceCard):
            if widget.width() < widget.minimumSizeHint().width():
                problems.append((label, "button", widget.text(), widget.width(), widget.minimumSizeHint().width()))
    for text_label in page.findChildren(QtWidgets.QLabel):
        text = text_label.text()
        if not visible(text_label) or not text or text_label.pixmap() is not None and not text:
            continue
        metrics = text_label.fontMetrics()
        area = text_label.contentsRect()
        if text_label.wordWrap():
            needed = metrics.boundingRect(QtCore.QRect(0, 0, max(1, area.width()), 10000),
                                          int(QtCore.Qt.TextFlag.TextWordWrap), text).height()
            if needed > area.height() + 1:
                problems.append((label, "wrapped label", text, area.height(), needed))
        elif metrics.horizontalAdvance(text) > area.width() + 1:
            problems.append((label, "label", text, area.width(), metrics.horizontalAdvance(text)))
    for spin in page.findChildren(QtWidgets.QAbstractSpinBox):
        if visible(spin):
            editor = spin.findChild(QtWidgets.QLineEdit)
            needed = editor.fontMetrics().horizontalAdvance(editor.text())
            if editor.width() < needed + 2:
                problems.append((label, "spinbox", editor.text(), editor.width(), needed))
    for field in page.findChildren(QtWidgets.QLineEdit):
        if visible(field) and not isinstance(field.parent(), QtWidgets.QAbstractSpinBox):
            if isinstance(field.parent(), QtWidgets.QComboBox):
                continue
            text = field.text() or field.placeholderText()
            if text and field.fontMetrics().horizontalAdvance(text) > field.width() - 16:
                if field.text():
                    continue  # typed text may scroll inside an editor by design
                problems.append((label, "placeholder", text, field.width()))
    for combo in page.findChildren(QtWidgets.QComboBox):
        if visible(combo) and combo.currentText():
            needed = combo.fontMetrics().horizontalAdvance(combo.currentText())
            if needed > combo.width() - 30:
                problems.append((label, "combo", combo.currentText(), combo.width(), needed))
    return problems


def test_no_clipping_or_overflow_across_pages_states_geometries() -> None:
    with _window() as (app, window, bridge):
        _load_rich_state(window)
        problems = []
        cases = [(w, h, False) for w, h in GEOMETRIES] + [(780, 720, True)]
        for width, height, maximized in cases:
            if maximized:
                window.showMaximized()
            else:
                window.showNormal()
                window.resize(width, height)
            _settle(app)
            for key in PAGES:
                window.shell.show_page(key)
                _settle(app)
                label = "%s %s" % (key, "maximized" if maximized else "%dx%d" % (width, height))
                view = window.shell.page_views[key]
                if view.horizontalScrollBar().maximum() != 0:
                    problems.append((label, "horizontal scroll", view.horizontalScrollBar().maximum()))
                page = window.shell.pages[key]
                if key == "styles" and page.controls_scroll.horizontalScrollBar().maximum() != 0:
                    problems.append((label, "controls horizontal scroll"))
                problems += _overflow_problems(page, label)
        window.showNormal()
        assert not problems, "\n".join(repr(item) for item in problems[:40])
        assert bridge.calls == []


def test_keyboard_reaches_every_primary_action_and_activates_it() -> None:
    with _window() as (app, window, _bridge):
        primaries = {
            "create": window.shell.pages["create"].start_button,
            "styles": window.shell.pages["styles"].apply_button,
            "edit": window.shell.pages["edit"].refresh_button,
            "render": window.shell.pages["render"].render_button,
            "config": window.shell.pages["config"].copy_button,
        }
        for key, target in primaries.items():
            window.shell.show_page(key)
            _settle(app)
            first = window.shell._nav_by_key[key]
            first.setFocus(QtCore.Qt.FocusReason.OtherFocusReason)
            _settle(app)
            seen = []
            for _ in range(80):
                QtTest.QTest.keyClick(QtWidgets.QApplication.focusWidget(), QtCore.Qt.Key.Key_Tab)
                focus = QtWidgets.QApplication.focusWidget()
                seen.append(focus)
                if focus is target:
                    break
            assert QtWidgets.QApplication.focusWidget() is target, key
            QtTest.QTest.keyClick(target, QtCore.Qt.Key.Key_Tab, QtCore.Qt.KeyboardModifier.ShiftModifier)
            assert QtWidgets.QApplication.focusWidget() is not target, key
            QtTest.QTest.keyClick(QtWidgets.QApplication.focusWidget(), QtCore.Qt.Key.Key_Tab)
            assert QtWidgets.QApplication.focusWidget() is target, key


def test_space_and_enter_activate_focused_controls() -> None:
    with _window() as (app, window, _bridge):
        rail = window.shell._nav_by_key["styles"]
        rail.setFocus()
        QtTest.QTest.keyClick(rail, QtCore.Qt.Key.Key_Space)
        _settle(app)
        assert window.shell.content.currentWidget() is window.shell.page_views["styles"]
        rail = window.shell._nav_by_key["create"]
        rail.setFocus()
        QtTest.QTest.keyClick(rail, QtCore.Qt.Key.Key_Return)
        _settle(app)
        assert window.shell.content.currentWidget() is window.shell.page_views["create"]
        page = window.shell.pages["create"]
        card = page.tool_choice._by_value["continuous"]
        card.setFocus()
        QtTest.QTest.keyClick(card, QtCore.Qt.Key.Key_Space)
        assert page.tool_choice.value() == "continuous"
        details = page.details.toggle
        details.setFocus()
        QtTest.QTest.keyClick(details, QtCore.Qt.Key.Key_Space)
        assert details.isChecked()


def test_icon_only_controls_have_names_and_tooltips() -> None:
    with _window() as (_app, window, _bridge):
        missing = []
        for widget in window.findChildren(QtWidgets.QAbstractButton):
            if widget.isVisibleTo(window) and not widget.text().strip() and not isinstance(widget, ChoiceCard):
                if not widget.accessibleName() or not widget.toolTip():
                    missing.append(widget.objectName() or type(widget).__name__)
        assert not missing, missing


def test_resize_navigation_and_slider_stay_fast() -> None:
    with _window() as (app, window, bridge):
        _load_rich_state(window)
        start = perf_counter()
        for index in range(24):
            width, height = GEOMETRIES[index % len(GEOMETRIES)]
            window.resize(width, height)
            app.processEvents()
        resize_ms = (perf_counter() - start) * 1000 / 24

        start = perf_counter()
        for index in range(50):
            window.shell.show_page(PAGES[index % len(PAGES)])
            app.processEvents()
        navigation_ms = (perf_counter() - start) * 1000 / 50

        window.shell.show_page("styles")
        page = window.shell.pages["styles"]
        _settle(app)
        start = perf_counter()
        for value in range(100):
            page.font_size.slider.setValue(value)
            page.preview.repaint()  # measure the synchronous paint, not a deferred one
        slider_ms = (perf_counter() - start) * 1000 / 100
        print("PERF resize=%.1fms navigation=%.1fms slider+preview=%.1fms" % (resize_ms, navigation_ms, slider_ms))
        assert resize_ms < 150, resize_ms
        assert navigation_ms < 60, navigation_ms
        assert slider_ms < 30, slider_ms
        assert bridge.calls == []


def test_one_hundred_lifecycle_cycles_leave_no_windows_or_scene_calls() -> None:
    app = _app()
    app.sendPostedEvents(None, QtCore.QEvent.Type.DeferredDelete)
    app.processEvents()
    baseline = len(QtWidgets.QApplication.topLevelWidgets())
    bridge = RecordingBridge()
    with tempfile.TemporaryDirectory(prefix="ameno-e20-lifecycle-") as directory:
        with patch.dict(os.environ, {"AMENO_SETTINGS_FILE": str(Path(directory) / "settings.ini")}):
            for cycle in range(100):
                window = AmenoMainWindow(bridge, lambda _token: None, lambda: None)
                window.show_application("create")
                window._frame_checked = True
                window.show()
                window.shell.show_page(PAGES[cycle % len(PAGES)])
                if cycle % 10 == 0:
                    window.showMaximized()
                    app.processEvents()
                    window.showNormal()
                app.processEvents()
                window.close()
                app.sendPostedEvents(None, QtCore.QEvent.Type.DeferredDelete)
                app.processEvents()
    assert bridge.calls == ["cancel"] * 100
    assert len(QtWidgets.QApplication.topLevelWidgets()) <= baseline
