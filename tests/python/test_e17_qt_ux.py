"""E17 presentation contracts; all tests run offscreen and without 3ds Max."""

from __future__ import annotations

import os
import sys
import tempfile
from pathlib import Path

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "Contents" / "python"))

from PySide6 import QtCore, QtGui, QtWidgets  # noqa: E402

from ameno_ui.application import AmenoApplication  # noqa: E402
from ameno_ui.assets import asset_path, pixmap  # noqa: E402
from ameno_ui.bridge import BridgeError  # noqa: E402
from ameno_ui.common import set_bridge_error  # noqa: E402
from ameno_ui.create_page import CreatePage  # noqa: E402
from ameno_ui.models import CreateSnapshot, SceneSnapshot, StyleSnapshot  # noqa: E402
from ameno_ui.theme import COLORS, register_fonts  # noqa: E402
from ameno_ui.window import AmenoMainWindow  # noqa: E402


def _app() -> QtWidgets.QApplication:
    return QtWidgets.QApplication.instance() or QtWidgets.QApplication([])


class CountingBridge:
    def __init__(self) -> None:
        self.calls = []
        self.snapshot = {
            "scene": SceneSnapshot(status="ready", status_label="Pronta", dimension_count=3),
            "create": CreateSnapshot(),
            "styles": [StyleSnapshot("default", "Arquitetônico")],
        }

    def cancel_interactive(self):
        self.calls.append(("cancel",))
        return True

    def set_create_settings(self, *args):
        self.calls.append(("settings",) + args)
        return True

    def start_individual(self):
        self.calls.append(("individual",))
        return self.snapshot

    def start_continuous(self):
        self.calls.append(("continuous",))
        return self.snapshot


def _settings_file() -> str:
    directory = Path(tempfile.mkdtemp(prefix="ameno-e17-settings-"))
    path = directory / "settings.ini"
    os.environ["AMENO_SETTINGS_FILE"] = str(path)
    return str(path)


def test_brand_assets_and_fonts_have_runtime_fallbacks() -> None:
    _app()
    assert asset_path("brand/ameno-wordmark-dark.png").is_file()
    assert asset_path("brand/ameno-symbol-red.png").is_file()
    assert pixmap("brand/ameno-wordmark-dark.png", 300, 70) is not None
    ui_family, mono_family = register_fonts()
    assert ui_family
    assert mono_family
    assert COLORS["red"] == "#E63B2E"


def test_theme_is_scoped_to_ameno_window() -> None:
    app = _app()
    _settings_file()
    before = app.styleSheet()
    bridge = CountingBridge()
    window = AmenoMainWindow(bridge, lambda _token: None, lambda: None)
    assert window.styleSheet()
    assert app.styleSheet() == before
    window.close()
    app.processEvents()


def test_navigation_is_local_and_widget_tree_is_stable_for_100_cycles() -> None:
    app = _app()
    _settings_file()
    bridge = CountingBridge()
    window = AmenoMainWindow(bridge, lambda _token: None, lambda: None)
    initial_pages = tuple(id(window.shell.pages[key]) for key in window.shell.pages)
    initial_views = tuple(id(window.shell.page_views[key]) for key in window.shell.page_views)
    initial_widgets = len(window.findChildren(QtWidgets.QWidget))
    bridge.calls.clear()
    for _ in range(100):
        for key in ("create", "styles", "edit", "render", "config"):
            window.shell.show_page(key)
    assert bridge.calls == []
    assert tuple(id(window.shell.pages[key]) for key in window.shell.pages) == initial_pages
    assert tuple(id(window.shell.page_views[key]) for key in window.shell.page_views) == initial_views
    assert len(window.findChildren(QtWidgets.QWidget)) == initial_widgets
    assert window.findChildren(QtCore.QTimer) == []
    window.close()
    app.processEvents()


def test_create_choices_remain_local_until_one_consolidated_start() -> None:
    app = _app()
    _settings_file()
    bridge = CountingBridge()
    page = CreatePage(bridge)
    page.load_styles([StyleSnapshot("default", "Arquitetônico")])
    bridge.calls.clear()
    page.tool_choice.set_value("continuous", emit=True)
    page.plane_choice.set_value("viewPlane", emit=True)
    page.mode.setCurrentIndex(page.mode.findData("vertical"))
    page.unit.setCurrentIndex(page.unit.findData("centimeters"))
    page.precision.setValue(1)
    page.follow_line.setChecked(False)
    app.processEvents()
    assert bridge.calls == []
    page.start_selected()
    assert len(bridge.calls) == 2
    assert bridge.calls[0][0] == "settings"
    assert bridge.calls[0][1:3] == ("vertical", "viewPlane")
    assert bridge.calls[1] == ("continuous",)


def test_all_previous_commands_remain_reachable_without_extra_primary_actions() -> None:
    _app()
    _settings_file()
    bridge = CountingBridge()
    window = AmenoMainWindow(bridge, lambda _token: None, lambda: None)
    create = window.shell.pages["create"]
    create_actions = {action.text() for action in create.more_menu.actions() if not action.isSeparator()}
    assert {
        "Atualizar estado da cena",
        "Preparar cena",
        "Reparar todas as cotas",
        "Excluir cotas selecionadas…",
        "Limpar cotas órfãs…",
        "Excluir todas as cotas…",
    } == create_actions
    primary_counts = {}
    for key, page in window.shell.pages.items():
        primary_counts[key] = sum(
            1 for widget in page.findChildren(QtWidgets.QPushButton) if bool(widget.property("primary"))
        )
    assert primary_counts == {"create": 1, "styles": 1, "edit": 1, "render": 1, "config": 0}
    window.close()


def test_login_never_serializes_token_and_help_never_reads_scene() -> None:
    app = _app()
    settings_path = _settings_file()
    bridge = CountingBridge()
    captured = []
    window = AmenoMainWindow(bridge, captured.append, lambda: None)
    secret = "E17-SECRET-DO-NOT-PERSIST"
    window.login_page.token.setText(secret)
    window.login_page.submit()
    assert captured == [secret]
    bridge.calls.clear()
    window.shell.show_help()
    assert bridge.calls == []
    window._save_geometry()
    app.processEvents()
    text = Path(settings_path).read_text(encoding="utf-8")
    assert secret not in text
    window.login_page.clear()
    window.close()


def test_logout_erases_token_widget_and_100_window_lifecycles_complete() -> None:
    app = _app()
    _settings_file()
    coordinator = AmenoApplication()
    bridge = CountingBridge()
    coordinator.bridge = bridge
    for index in range(100):
        coordinator.show("login")
        window = coordinator.window
        assert window is not None
        secret = "SESSION-%d" % index
        window.login_page.token.setText(secret)
        coordinator.authenticate(secret)
        assert coordinator.auth.authenticated
        assert window.stack.currentWidget() is window.shell
        coordinator.logout()
        assert not coordinator.auth.authenticated
        assert window.login_page.token.text() == ""
        assert window.stack.currentWidget() is window.login_page
        coordinator.close()
        app.processEvents()
        assert coordinator.window is None


def test_layout_renders_at_minimum_default_and_large_sizes() -> None:
    app = _app()
    _settings_file()
    bridge = CountingBridge()
    window = AmenoMainWindow(bridge, lambda _token: None, lambda: None)
    window.show_application("create")
    window.show()
    for width, height in ((780, 560), (980, 720), (1560, 1000)):
        window.resize(width, height)
        for key, view in window.shell.page_views.items():
            window.shell.show_page(key)
            app.processEvents()
            assert view.widget() is window.shell.pages[key]
            if key == "styles":
                # E19 gives Estilo a fixed shell with its own controls-only
                # scroll region so preview and footer never leave the screen.
                assert not view.widgetResizable()
                assert view.verticalScrollBar().maximum() == 0
            else:
                assert view.widgetResizable()
            image = QtGui.QImage(window.size(), QtGui.QImage.Format.Format_ARGB32)
            image.fill(0)
            window.render(image)
            assert not image.isNull()
    create = window.shell.pages["create"]
    assert all(button.accessibleName() for button in create.tool_choice.buttons.buttons())
    assert all(button.accessibleName() for button in create.plane_choice.buttons.buttons())
    window.close()
    app.processEvents()


def test_bridge_errors_are_translated_to_an_actionable_next_step() -> None:
    _app()
    label = QtWidgets.QLabel()
    set_bridge_error(label, BridgeError("noSelection", "internal selection detail"))
    assert "Selecione uma cota Ameno" in label.text()
    assert label.property("errorCode") == "noSelection"
    assert "internal selection detail" in label.toolTip()
    set_bridge_error(label, BridgeError("bridgeUnavailable", ".NET proxy failure"))
    assert "reinicie o 3ds Max" in label.text()
