"""E18.5 responsive shell and no-horizontal-overflow contracts."""

from __future__ import annotations

import os
import subprocess
import sys
import tempfile
from pathlib import Path

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "Contents" / "python"))

from PySide6 import QtWidgets  # noqa: E402

from ameno_ui.responsive import spec_for_width  # noqa: E402
from ameno_ui.window import AmenoMainWindow  # noqa: E402


def _app() -> QtWidgets.QApplication:
    return QtWidgets.QApplication.instance() or QtWidgets.QApplication([])


class ResponsiveBridge:
    def __init__(self) -> None:
        self.calls = []

    def cancel_interactive(self):
        self.calls.append("cancel")
        return True


def test_breakpoints_are_pure_and_have_no_ambiguous_boundary() -> None:
    assert spec_for_width(780).mode == "compact"
    assert spec_for_width(899).mode == "compact"
    assert spec_for_width(900).mode == "medium"
    assert spec_for_width(1279).mode == "medium"
    assert spec_for_width(1280).mode == "wide"
    assert spec_for_width(1560).sidebar_width == 208
    assert spec_for_width(780).page_margin == 16


def test_shell_uses_rail_medium_and_wide_sidebar_without_rebuilding_pages() -> None:
    app = _app()
    bridge = ResponsiveBridge()
    window = AmenoMainWindow(bridge, lambda _token: None, lambda: None)
    page_ids = {key: id(page) for key, page in window.shell.pages.items()}
    view_ids = {key: id(view) for key, view in window.shell.page_views.items()}
    window.show_application("create")
    window.show()
    for width, expected_mode, expected_sidebar in (
        (780, "compact", 64),
        (980, "medium", 184),
        (1280, "wide", 208),
        (1560, "wide", 208),
    ):
        window.resize(width, 800)
        app.processEvents()
        assert window.shell._responsive_mode == expected_mode
        assert window.shell.sidebar.width() == expected_sidebar
        assert {key: id(page) for key, page in window.shell.pages.items()} == page_ids
        assert {key: id(view) for key, view in window.shell.page_views.items()} == view_ids
    window.close()
    app.processEvents()


def test_all_pages_have_no_horizontal_scroll_at_supported_window_widths() -> None:
    app = _app()
    window = AmenoMainWindow(ResponsiveBridge(), lambda _token: None, lambda: None)
    window.show_application("create")
    window.show()
    for width, height in ((780, 560), (980, 720), (1120, 760), (1280, 800), (1560, 1000)):
        window.resize(width, height)
        for key, view in window.shell.page_views.items():
            window.shell.show_page(key)
            app.processEvents()
            assert view.horizontalScrollBar().maximum() == 0, (key, width, height)
            assert view.widget().minimumSizeHint().width() <= view.viewport().width()
    window.close()
    app.processEvents()


def test_compact_layout_survives_common_windows_dpi_scales() -> None:
    code = """
import os, sys
os.environ["QT_QPA_PLATFORM"] = "offscreen"
sys.path.insert(0, %r)
from PySide6 import QtWidgets
from ameno_ui.window import AmenoMainWindow
class B:
    def cancel_interactive(self):
        return True
app = QtWidgets.QApplication.instance() or QtWidgets.QApplication([])
window = AmenoMainWindow(B(), lambda token: None, lambda: None)
window.resize(780, 560)
window.show_application("create")
window.show()
app.processEvents()
for view in window.shell.page_views.values():
    assert view.horizontalScrollBar().maximum() == 0
window.close()
""" % str(ROOT / "Contents" / "python")
    with tempfile.TemporaryDirectory(prefix="ameno-e18-dpi-") as directory:
        for scale in ("1.0", "1.25", "1.5", "2.0"):
            environment = os.environ.copy()
            environment["QT_QPA_PLATFORM"] = "offscreen"
            environment["QT_SCALE_FACTOR"] = scale
            environment["QT_AUTO_SCREEN_SCALE_FACTOR"] = "0"
            environment["AMENO_SETTINGS_FILE"] = str(Path(directory) / (scale + ".ini"))
            result = subprocess.run(
                [sys.executable, "-c", code],
                env=environment,
                capture_output=True,
                text=True,
                timeout=20,
            )
            assert result.returncode == 0, "%s: %s%s" % (scale, result.stdout, result.stderr)
