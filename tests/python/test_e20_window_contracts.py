"""E20.0 behavioral REDs for window persistence and usable monitor geometry."""

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
from ameno_ui.window import AmenoMainWindow  # noqa: E402


class LocalBridge:
    def cancel_interactive(self):
        return True


@contextmanager
def _isolated_windows():
    app = QtWidgets.QApplication.instance() or QtWidgets.QApplication([])
    windows = []
    with tempfile.TemporaryDirectory(prefix="ameno-e20-window-") as directory:
        with patch.dict(os.environ, {"AMENO_SETTINGS_FILE": str(Path(directory) / "settings.ini")}):
            def create():
                window = AmenoMainWindow(LocalBridge(), lambda _token: None, lambda: None)
                windows.append(window)
                return window

            try:
                yield app, create
            finally:
                for window in windows:
                    window.close()
                app.sendPostedEvents(None, QtCore.QEvent.Type.DeferredDelete)
                app.processEvents()


def test_reopening_preserves_restored_size_or_recovers_if_it_no_longer_fits() -> None:
    # 780x600 fits the 96-DPI offscreen monitor but not its 144-DPI logical
    # area. Observe real Qt restoration, rather than demanding an invalid
    # saved size be preserved after a monitor/DPI change.
    with _isolated_windows() as (app, create):
        first = create()
        first.resize(780, 600)
        first._save_geometry()
        restored = []
        restore_geometry = AmenoMainWindow.restoreGeometry

        def observe_restore(window, geometry):
            accepted = restore_geometry(window, geometry)
            restored.append((accepted, QtCore.QSize(window.size())))
            return accepted

        with patch.object(AmenoMainWindow, "restoreGeometry", new=observe_restore):
            second = create()
        assert len(restored) == 1 and restored[0][0], "saved Qt geometry was not restored"
        size = restored[0][1]
        area = second.screen().availableGeometry()
        if size.width() <= area.width() and size.height() <= area.height():
            assert second.size() == size, (
                "valid restored size %sx%s was replaced by %sx%s"
                % (size.width(), size.height(), second.width(), second.height())
            )
        else:
            assert second.width() <= area.width() and second.height() <= area.height(), (
                "invalid restored size must be recovered: window %sx%s exceeds %sx%s"
                % (second.width(), second.height(), area.width(), area.height())
            )


def test_first_open_uses_portrait_when_the_monitor_has_room() -> None:
    monitor = SimpleNamespace(availableGeometry=lambda: QtCore.QRect(0, 0, 1280, 1200))
    with _isolated_windows() as (app, create):
        with patch.object(AmenoMainWindow, "screen", return_value=monitor):
            window = create()
        assert window.height() > window.width(), (
            "first open should use portrait on a spacious monitor, got %sx%s"
            % (window.width(), window.height())
        )


def test_first_open_fits_a_small_available_monitor() -> None:
    area = QtCore.QRect(0, 0, 640, 720)
    monitor = SimpleNamespace(availableGeometry=lambda: area)
    with _isolated_windows() as (app, create):
        with patch.object(AmenoMainWindow, "screen", return_value=monitor):
            window = create()
        assert window.width() <= area.width() and window.height() <= area.height(), (
            "window %sx%s exceeds available monitor %sx%s"
            % (window.width(), window.height(), area.width(), area.height())
        )


def test_cotar_primary_action_fits_the_offscreen_control_at_780x720() -> None:
    # Positive control: stock offscreen metrics pass where the user's real
    # host screenshot clips. This must not be presented as host acceptance.
    with _isolated_windows() as (app, create):
        window = create()
        window.resize(780, 720)
        window.show_application("create")
        window.show()
        page = window.shell.pages["create"]
        page.tool_choice.set_value("continuous", emit=True)
        for _ in range(3):
            app.processEvents()
        viewport = window.shell.page_views["create"].viewport()
        start = page.start_button.mapTo(viewport, QtCore.QPoint(0, 0))
        rect = QtCore.QRect(start, page.start_button.size())
        assert viewport.rect().contains(rect), (
            "Iniciar cotação rect %r exceeds first viewport %r (logical DPI %.0f)"
            % (rect.getRect(), viewport.rect().getRect(), window.logicalDpiY())
        )
