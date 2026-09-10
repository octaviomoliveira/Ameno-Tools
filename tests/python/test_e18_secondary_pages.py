"""E18.7 contracts for secondary-page clarity and explicit actions."""

from __future__ import annotations

import os
import sys
from pathlib import Path

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "Contents" / "python"))

from PySide6 import QtWidgets  # noqa: E402

from ameno_ui.window import AmenoMainWindow  # noqa: E402


def _app() -> QtWidgets.QApplication:
    return QtWidgets.QApplication.instance() or QtWidgets.QApplication([])


class SecondaryBridge:
    def __init__(self) -> None:
        self.calls = []

    def cancel_interactive(self):
        self.calls.append("cancel")
        return True


def test_login_explains_token_and_has_named_primary_action() -> None:
    _app()
    window = AmenoMainWindow(SecondaryBridge(), lambda _token: None, lambda: None)
    assert window.login_page.token.accessibleName()
    assert "token" in window.login_page.token.placeholderText().lower()
    assert window.login_page.enter.property("primary") is True
    assert window.login_page.cancel.accessibleName()
    window.close()


def test_secondary_pages_have_actionable_headings_and_one_primary_each() -> None:
    _app()
    window = AmenoMainWindow(SecondaryBridge(), lambda _token: None, lambda: None)
    pages = window.shell.pages
    assert "Leia a medida" in pages["edit"].findChild(QtWidgets.QLabel, "PageSubtitle").text()
    assert "Escolha o arquivo" in pages["render"].findChild(QtWidgets.QLabel, "PageSubtitle").text()
    assert "token nunca" in pages["config"].findChild(QtWidgets.QLabel, "PageSubtitle").text()
    for key in ("edit", "render"):
        assert sum(
            1
            for widget in pages[key].findChildren(QtWidgets.QPushButton)
            if widget.property("primary")
        ) == 1
    window.close()


def test_navigation_between_secondary_pages_stays_local() -> None:
    _app()
    bridge = SecondaryBridge()
    window = AmenoMainWindow(bridge, lambda _token: None, lambda: None)
    for key in ("edit", "render", "config", "create"):
        window.shell.show_page(key)
    assert bridge.calls == []
    window.close()
