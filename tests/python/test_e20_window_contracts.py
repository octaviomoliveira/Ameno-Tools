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
from ameno_ui.preferences import settings  # noqa: E402
from ameno_ui.window import AmenoMainWindow  # noqa: E402
from ameno_ui.window_geometry import (  # noqa: E402
    initial_window_geometry,
    recover_window_geometry,
    remap_window_geometry,
    visible_enough,
)


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


def _safe_test_rect(window: AmenoMainWindow) -> QtCore.QRect:
    area = window.screen().availableGeometry()
    width = min(520, max(1, area.width() - 80))
    height = min(650, max(1, area.height() - 80))
    return QtCore.QRect(area.left() + 40, area.top() + 40, width, height)


def test_reopening_preserves_restored_size_or_recovers_if_it_no_longer_fits() -> None:
    # 780x600 fits the 96-DPI offscreen monitor but not its 144-DPI logical
    # area. Observe real Qt restoration, rather than demanding an invalid
    # saved size be preserved after a monitor/DPI change.
    with _isolated_windows() as (app, create):
        first = create()
        saved_normal = QtCore.QRect(10, 50, 780, 600)
        first.setGeometry(saved_normal)
        first._save_geometry()
        restored = []
        restore_geometry = AmenoMainWindow.restoreGeometry

        def observe_restore(window, geometry):
            accepted = restore_geometry(window, geometry)
            restored.append((accepted, QtCore.QRect(window.geometry())))
            return accepted

        with patch.object(AmenoMainWindow, "restoreGeometry", new=observe_restore):
            second = create()
        assert len(restored) == 1 and restored[0][0], "saved Qt geometry was not restored"
        area = second.screen().availableGeometry()
        if area.contains(saved_normal):
            assert second.geometry() == saved_normal, (
                "valid saved geometry %r was replaced by %r"
                % (saved_normal.getRect(), second.geometry().getRect())
            )
        else:
            assert area.contains(second.geometry()), (
                "invalid saved geometry must be recovered: window %r exceeds %r"
                % (second.geometry().getRect(), area.getRect())
            )


def test_first_open_uses_portrait_when_the_monitor_has_room() -> None:
    area = QtCore.QRect(0, 0, 1280, 1200)
    monitor = SimpleNamespace(availableGeometry=lambda: area)
    with _isolated_windows() as (app, create):
        with patch.object(AmenoMainWindow, "screen", return_value=monitor):
            window = create()
        assert window.geometry() == initial_window_geometry(area)
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
        assert window.height() > window.width()


def test_initial_portrait_scales_uniformly_inside_small_available_area() -> None:
    area = QtCore.QRect(1600, 40, 640, 720)
    geometry = initial_window_geometry(area)
    assert area.contains(geometry)
    assert geometry.height() > geometry.width()
    assert abs((geometry.width() / geometry.height()) - (780 / 1020)) < 0.002
    assert geometry.center() == area.center()


def test_recovery_preserves_safe_position_and_size() -> None:
    available = QtCore.QRect(0, 0, 1920, 1040)
    restored = QtCore.QRect(220, 15, 780, 1020)
    assert recover_window_geometry(restored, [available], available) == restored
    assert visible_enough(restored, [available])


def test_recovery_moves_removed_monitor_geometry_onto_preferred_monitor() -> None:
    primary = QtCore.QRect(0, 0, 1920, 1080)
    restored = QtCore.QRect(4200, -1600, 780, 1020)
    recovered = recover_window_geometry(restored, [primary], primary)
    assert primary.contains(recovered)
    assert recovered.size() == restored.size()
    assert not visible_enough(restored, [primary])


def test_recovery_clamps_oversized_saved_geometry() -> None:
    available = QtCore.QRect(-1280, 0, 1280, 720)
    recovered = recover_window_geometry(QtCore.QRect(-1500, -100, 1800, 1200), [available], available)
    assert recovered == available.adjusted(12, 12, -12, -12)


def test_invalid_rect_uses_a_usable_portrait_fallback() -> None:
    available = QtCore.QRect(-1280, 0, 1280, 720)
    recovered = recover_window_geometry(QtCore.QRect(), [available], available)
    assert available.contains(recovered)
    assert recovered.height() > recovered.width()


def test_same_monitor_resolution_change_preserves_relative_placement() -> None:
    old_area = QtCore.QRect(-1920, 0, 1920, 1080)
    new_area = QtCore.QRect(-2560, 40, 2560, 1400)
    saved = QtCore.QRect(-1350, 30, 780, 1020)
    remapped = remap_window_geometry(saved, old_area, new_area)
    assert remapped.size() == saved.size()
    old_x_ratio = (saved.left() - old_area.left()) / (old_area.width() - saved.width())
    new_x_ratio = (remapped.left() - new_area.left()) / (new_area.width() - saved.width())
    assert abs(old_x_ratio - new_x_ratio) < 0.001
    assert new_area.contains(remapped)


def test_saved_screen_identity_drives_resolution_remap() -> None:
    old_area = QtCore.QRect(-1920, 0, 1920, 1080)
    new_area = QtCore.QRect(-2560, 40, 2560, 1400)
    saved = QtCore.QRect(-1350, 30, 780, 1020)
    monitor = SimpleNamespace(availableGeometry=lambda: new_area)
    with _isolated_windows() as (app, create):
        preferences = settings()
        preferences.setValue("window/normalGeometry", saved)
        preferences.setValue("window/screenSerial", "SERIAL-A")
        preferences.setValue("window/screenName", "DISPLAY-A")
        preferences.setValue("window/screenAvailableGeometry", old_area)
        records = [("SERIAL-A", "DISPLAY-A", new_area)]
        with patch.object(AmenoMainWindow, "screen", return_value=monitor), patch.object(
            AmenoMainWindow, "_screen_records", return_value=records
        ):
            window = create()
        expected = recover_window_geometry(
            remap_window_geometry(saved, old_area, new_area), [new_area], new_area
        )
        assert window.geometry() == expected


def test_reopening_preserves_a_valid_position_and_size() -> None:
    with _isolated_windows() as (app, create):
        first = create()
        expected = _safe_test_rect(first)
        first.setGeometry(expected)
        first._save_geometry()
        second = create()
        assert second.geometry() == expected


def test_invalid_saved_blob_falls_back_to_the_current_monitor_portrait() -> None:
    with _isolated_windows() as (app, create):
        settings().setValue("window/geometry", QtCore.QByteArray(b"not-a-qt-geometry"))
        window = create()
        area = window.screen().availableGeometry()
        assert window.geometry() == initial_window_geometry(area)


def test_inaccessible_geometry_does_not_replace_the_last_good_restore_point() -> None:
    with _isolated_windows() as (app, create):
        window = create()
        window.setGeometry(_safe_test_rect(window))
        window._save_geometry()
        before = bytes(settings().value("window/geometry"))
        window.move(5000, 5000)
        window._save_geometry()
        after = bytes(settings().value("window/geometry"))
        assert after == before


def test_window_has_no_fixed_product_minimum() -> None:
    with _isolated_windows() as (app, create):
        window = create()
        assert window.minimumWidth() < 780 and window.minimumHeight() < 560
        assert window.minimumSizeHint().width() < 780
        assert window.minimumSizeHint().height() < 560


def test_native_frame_is_inside_the_current_available_area_after_show() -> None:
    with _isolated_windows() as (app, create):
        window = create()
        window.show()
        app.processEvents()
        assert window.screen().availableGeometry().contains(window.frameGeometry())


def test_maximized_state_roundtrips_separately_from_normal_geometry() -> None:
    with _isolated_windows() as (app, create):
        first = create()
        first.setGeometry(_safe_test_rect(first))
        first.show()
        app.processEvents()
        first.showMaximized()
        app.processEvents()
        first._save_geometry()
        assert settings().value("window/normalGeometry") == _safe_test_rect(first)
        second = create()
        assert bool(second.windowState() & QtCore.Qt.WindowState.WindowMaximized)


def test_closing_minimized_after_maximized_reopens_maximized() -> None:
    with _isolated_windows() as (app, create):
        first = create()
        first.setGeometry(_safe_test_rect(first))
        first.show()
        first.showMaximized()
        app.processEvents()
        first.showMinimized()
        app.processEvents()
        first._save_geometry()
        assert settings().value("window/maximized", False) is True
        second = create()
        assert bool(second.windowState() & QtCore.Qt.WindowState.WindowMaximized)


def test_closing_minimized_after_normal_reopens_normal() -> None:
    with _isolated_windows() as (app, create):
        first = create()
        first.setGeometry(_safe_test_rect(first))
        first.show()
        app.processEvents()
        first.showMinimized()
        app.processEvents()
        first._save_geometry()
        assert settings().value("window/maximized", True) is False
        second = create()
        assert not bool(second.windowState() & QtCore.Qt.WindowState.WindowMaximized)


def test_restoring_a_saved_maximized_window_runs_the_native_frame_check() -> None:
    with _isolated_windows() as (app, create):
        settings().setValue("window/maximized", True)
        window = create()
        window.show()
        app.processEvents()
        assert window.isMaximized()
        assert not window._frame_checked
        window.showNormal()
        app.processEvents()
        assert window._frame_checked
        assert window.screen().availableGeometry().contains(window.frameGeometry())


def test_cotar_primary_action_fits_780x720_or_is_scroll_reachable_on_smaller_monitor() -> None:
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
        if not viewport.rect().contains(rect):
            view = window.shell.page_views["create"]
            assert view.horizontalScrollBar().maximum() == 0
            assert view.verticalScrollBar().maximum() > 0
            assert page.start_button.width() <= viewport.width()
