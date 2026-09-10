"""E18.8 Ameno icon and compact-navigation contracts."""

from __future__ import annotations

import os
import sys
from pathlib import Path

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "Contents" / "python"))

from PySide6 import QtCore, QtWidgets  # noqa: E402

from ameno_ui.assets import asset_path, nav_icon  # noqa: E402
from ameno_ui.window import AmenoMainWindow  # noqa: E402


def _app() -> QtWidgets.QApplication:
    return QtWidgets.QApplication.instance() or QtWidgets.QApplication([])


class IconBridge:
    def cancel_interactive(self):
        return True


def test_all_navigation_icons_are_local_svg_assets_with_safe_fallback() -> None:
    _app()
    names = ("cotar", "aparencia", "revisar", "exportar", "configuracao", "ajuda")
    for name in names:
        path = asset_path("icons/%s.svg" % name)
        assert path.is_file()
        assert "<svg" in path.read_text(encoding="utf-8")
        assert not nav_icon(name).isNull()


def test_compact_rail_uses_icons_but_keeps_accessible_names_and_tooltips() -> None:
    app = _app()
    window = AmenoMainWindow(IconBridge(), lambda _token: None, lambda: None)
    window.resize(780, 560)
    window.show_application("create")
    window.show()
    app.processEvents()
    for key, button in window.shell._nav_by_key.items():
        assert button.text() == ""
        assert not button.icon().isNull()
        assert button.accessibleName()
        assert button.toolTip()
    assert window.shell.help_button.text() == "?"
    assert window.shell.help_button.toolTip() == "Como começar"
    assert window.shell.sidebar.width() == 64
    window.close()


def test_wide_navigation_keeps_labels_and_icons() -> None:
    _app()
    window = AmenoMainWindow(IconBridge(), lambda _token: None, lambda: None)
    window.resize(1280, 800)
    window.show_application("create")
    window.show()
    QtWidgets.QApplication.processEvents()
    assert window.shell._nav_by_key["create"].text() == "Cotar"
    assert not window.shell._nav_by_key["create"].icon().isNull()
    assert window.shell.sidebar.width() == 208
    window.close()
