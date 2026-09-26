"""E20.5 contracts for the adaptive Estilos workspace and its semantics."""

from __future__ import annotations

import os
import sys
import tempfile
from contextlib import contextmanager
from pathlib import Path
from types import SimpleNamespace
from unittest.mock import patch

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "Contents" / "python"))

from PySide6 import QtCore, QtWidgets  # noqa: E402

from ameno_ui.bridge import BridgeError, UiBridge  # noqa: E402
from ameno_ui.models import StyleSnapshot  # noqa: E402
from ameno_ui.window import AmenoMainWindow  # noqa: E402


STYLES = [
    StyleSnapshot("default", "Arquitetônico"),
    StyleSnapshot("technical", "Técnico", terminal_type="arrowClosed", terminal_size=110),
]
DIMENSIONAL = ("font_size", "text_gap", "line_thickness", "overhang", "extension_gap", "terminal_size")


class StylesBridge:
    def __init__(self) -> None:
        self.calls: list[tuple] = []
        self.fail_save = False

    def cancel_interactive(self):
        return True

    def styles(self):
        self.calls.append(("styles",))
        return list(STYLES)

    def save_style(self, style):
        self.calls.append(("save", style.style_id, style.font_size))
        if self.fail_save:
            raise BridgeError("styleSaveFailed", "falha simulada")
        return 4

    def apply_style(self, style_id, all_dimensions):
        self.calls.append(("apply", style_id, all_dimensions))
        return 2


def test_real_bridge_passes_maxscript_keyword_parameter() -> None:
    class Service:
        def __init__(self):
            self.calls = []

        def applyStyleCommand(self, style_id, *, allDimensions=False):
            self.calls.append((style_id, allDimensions))
            return [True, "ok", "", 2]

    service = Service()
    bridge = UiBridge()
    bridge._rt = SimpleNamespace(AmenoUiBridge=service)
    assert bridge.apply_style("technical") == 2
    assert bridge.apply_style("default", all_dimensions=True) == 2
    assert service.calls == [("technical", False), ("default", True)]


@contextmanager
def _page(width: int = 780, height: int = 1020):
    app = QtWidgets.QApplication.instance() or QtWidgets.QApplication([])
    bridge = StylesBridge()
    with tempfile.TemporaryDirectory(prefix="ameno-e20-styles-") as directory:
        with patch.dict(os.environ, {"AMENO_SETTINGS_FILE": str(Path(directory) / "settings.ini")}):
            window = AmenoMainWindow(bridge, lambda _token: None, lambda: None)
            window.show_application("styles")
            window._frame_checked = True
            window.resize(width, height)
            window.show()
            page = window.shell.pages["styles"]
            page.load_styles(list(STYLES))
            for _ in range(3):
                app.processEvents()
            try:
                yield app, window, page, bridge
            finally:
                window.close()
                app.sendPostedEvents(None, QtCore.QEvent.Type.DeferredDelete)
                app.processEvents()


@contextmanager
def _answer(button):
    calls = []

    def fake(*args, **kwargs):
        calls.append(args)
        return button

    with patch.object(QtWidgets.QMessageBox, "question", fake):
        yield calls


def test_apply_and_save_state_their_destination() -> None:
    with _page() as (_app, _window, page, _bridge):
        assert page.apply_button.text() == "Aplicar"
        assert not page.save_button.isEnabled()
        page.font_size.setValue(200)
        assert page.draft.dirty
        assert page.apply_button.text() == "Salvar e aplicar"
        assert page.save_button.isEnabled()
        assert "salv" in page.apply_selected_action.text().lower()
        assert "salv" in page.apply_all_action.text().lower()
        assert "cotas que já usam" in page.save_button.toolTip()


def test_save_and_apply_persists_the_draft_before_applying_it() -> None:
    with _page() as (_app, _window, page, bridge):
        page.font_size.setValue(200)
        bridge.calls.clear()
        page.apply_button.click()
        assert bridge.calls[0] == ("save", "default", 200.0)
        assert ("apply", "default", False) in bridge.calls
        assert bridge.calls.index(("apply", "default", False)) > 0
        assert not page.draft.dirty
        assert page.apply_button.text() == "Aplicar"
        text = page.status.text()
        assert "salvo" in text.lower() and "2" in text and "4" in text


def test_failed_save_never_applies_and_keeps_the_draft() -> None:
    with _page() as (_app, _window, page, bridge):
        page.font_size.setValue(200)
        bridge.fail_save = True
        bridge.calls.clear()
        page.apply_button.click()
        assert [call[0] for call in bridge.calls] == ["save"]
        assert page.draft.dirty
        assert page.font_size.value() == 200.0
        assert page.status.property("error") is True


def test_clean_apply_uses_the_saved_style_directly() -> None:
    with _page() as (_app, _window, page, bridge):
        bridge.calls.clear()
        page.apply_all_action.trigger()
        assert bridge.calls == [("apply", "default", True)]
        assert "2" in page.status.text()


def test_unsupported_terminal_controls_are_hidden_and_diamond_is_offered() -> None:
    with _page() as (_app, _window, page, _bridge):
        assert not page.placement.isVisibleTo(page)
        assert not page.terminal_angle.isVisibleTo(page)
        index = page.terminal.findData("diamond")
        assert index >= 0 and page.terminal.itemText(index) == "Losango"
        page.terminal.setCurrentIndex(index)
        assert page.draft.value("terminal_type") == "diamond"


def test_display_unit_changes_presentation_but_preserves_physical_values() -> None:
    with _page() as (_app, _window, page, _bridge):
        assert [page.unit.itemData(i) for i in range(page.unit.count())] == ["mm", "cm", "m"]
        page.unit.setCurrentIndex(page.unit.findData("cm"))
        for name in DIMENSIONAL:
            control = getattr(page, name)
            assert control.spinbox.suffix().strip() == "cm", name
        assert page.font_size.spinbox.value() == 14.0
        assert page.font_size.value() == 140.0
        assert page.tracking.spinbox.suffix() == ""
        assert not page.draft.dirty
        page.font_size.spinbox.setValue(20.0)
        assert page.draft.value("font_size") == 200.0
        page.unit.setCurrentIndex(page.unit.findData("m"))
        assert page.line_thickness.spinbox.suffix().strip() == "m"
        assert abs(page.line_thickness.spinbox.value() - 0.0015) < 1e-9
        assert page.draft.value("font_size") == 200.0


def test_switching_style_protects_the_draft() -> None:
    with _page() as (_app, _window, page, bridge):
        page.font_size.setValue(222)
        with _answer(QtWidgets.QMessageBox.StandardButton.Cancel) as asked:
            page.style_selector.setCurrentIndex(1)
        assert len(asked) == 1
        assert page.style_selector.currentIndex() == 0
        assert page.draft.value("font_size") == 222.0
        assert page.draft.dirty

        with _answer(QtWidgets.QMessageBox.StandardButton.Discard):
            page.style_selector.setCurrentIndex(1)
        assert page.draft.value("terminal_type") == "arrowClosed"
        assert not page.draft.dirty
        assert not any(call[0] == "save" for call in bridge.calls)


def test_background_style_reload_keeps_an_unsaved_draft() -> None:
    with _page() as (_app, _window, page, _bridge):
        page.font_size.setValue(222)
        page.load_styles(list(STYLES))
        assert page.draft.dirty
        assert page.font_size.value() == 222.0


def test_workspace_regions_never_cover_each_other() -> None:
    with _page() as (app, window, page, _bridge):
        view = window.shell.page_views["styles"]
        for width, height in ((780, 1020), (780, 720), (980, 720), (1280, 800), (780, 560)):
            window.resize(width, height)
            for _ in range(3):
                app.processEvents()
            label = "%dx%d" % (width, height)
            assert view.horizontalScrollBar().maximum() == 0, label

            def rect(widget):
                return QtCore.QRect(widget.mapTo(page, QtCore.QPoint(0, 0)), widget.size())

            preview, controls, footer = rect(page.preview_box), rect(page.controls_scroll), rect(page.footer)
            assert not preview.intersects(controls), label
            assert not preview.intersects(footer) and not controls.intersects(footer), label
            assert page.rect().contains(footer), label
            # The last control is reachable inside the controls scroll.
            bar = page.controls_scroll.verticalScrollBar()
            bar.setValue(bar.maximum())
            app.processEvents()
            last = page.mask
            top_left = last.mapTo(page.controls_scroll.viewport(), QtCore.QPoint(0, 0))
            assert page.controls_scroll.viewport().rect().contains(QtCore.QRect(top_left, last.size())), label
            bar.setValue(0)
