"""E20.3 contracts for the vertical Cotar flow."""

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

from ameno_ui.models import CreateSnapshot, SceneSnapshot, StyleSnapshot  # noqa: E402
from ameno_ui.window import AmenoMainWindow  # noqa: E402


SCENES = {
    "notPrepared": SceneSnapshot("notPrepared", "Não preparada", "Clique em Preparar esta cena."),
    "requiresRepair": SceneSnapshot(
        "requiresRepair", "Requer reparo", "A infraestrutura Ameno está incompleta e pode ser reparada."
    ),
    "error": SceneSnapshot("error", "Erro ao preparar", "Falha simulada."),
    "ready": SceneSnapshot("ready", "Cena preparada", "Layers: Ameno Cotas · Ameno Sistema", 3),
}


class SceneBridge:
    """Records every scene command; answers with a configurable scene state."""

    def __init__(self, scene: SceneSnapshot | None = None) -> None:
        self.calls: list[str] = []
        self.scene = scene or SCENES["notPrepared"]
        self.after_prepare: SceneSnapshot | None = None
        self.during_tool = None

    def cancel_interactive(self):
        self.calls.append("cancel")
        return True

    def _snapshot(self):
        return {
            "styles": [StyleSnapshot("default", "Arquitetônico")],
            "scene": self.scene,
            "create": CreateSnapshot(),
        }

    def refresh(self):
        self.calls.append("refresh")
        return self._snapshot()

    def prepare_scene(self):
        self.calls.append("prepare")
        if self.after_prepare is not None:
            self.scene = self.after_prepare
        return {"status": self.scene.status, "label": self.scene.status_label,
                "detail": self.scene.detail, "scene": self.scene}

    def set_create_settings(self, *args):
        self.calls.append("settings")
        return True

    def _tool(self, name: str):
        self.calls.append(name)
        if self.during_tool is not None:
            self.during_tool()
        return self._snapshot()

    def start_individual(self):
        return self._tool("individual")

    def start_continuous(self):
        return self._tool("continuous")


@contextmanager
def _window(width: int = 780, height: int = 1020, bridge: SceneBridge | None = None):
    app = QtWidgets.QApplication.instance() or QtWidgets.QApplication([])
    bridge = bridge or SceneBridge()
    with tempfile.TemporaryDirectory(prefix="ameno-e20-cotar-") as directory:
        with patch.dict(os.environ, {"AMENO_SETTINGS_FILE": str(Path(directory) / "settings.ini")}):
            window = AmenoMainWindow(bridge, lambda _token: None, lambda: None)
            window.show_application("create")
            # Synthetic canvases may exceed Qt offscreen's 800 px monitor;
            # native-frame recovery is covered by the E20.1 contracts.
            window._frame_checked = True
            window.resize(width, height)
            window.show()
            for _ in range(3):
                app.processEvents()
            try:
                yield app, window, window.shell.pages["create"], bridge
            finally:
                window.close()
                app.sendPostedEvents(None, QtCore.QEvent.Type.DeferredDelete)
                app.processEvents()


def _settle(app: QtWidgets.QApplication) -> None:
    for _ in range(3):
        app.processEvents()


def _fully_visible(widget: QtWidgets.QWidget, view: QtWidgets.QAbstractScrollArea) -> bool:
    top_left = widget.mapTo(view.viewport(), QtCore.QPoint(0, 0))
    return view.viewport().rect().contains(QtCore.QRect(top_left, widget.size()))


def test_scene_action_follows_the_real_scene_state() -> None:
    expected = {
        "notPrepared": ("Preparar cena", "idle"),
        "requiresRepair": ("Reparar cena", "warning"),
        "error": ("Tentar novamente", "error"),
        "ready": ("Atualizar estado", "ready"),
    }
    with _window() as (app, _window_, page, _bridge):
        assert page.scene_status.text() == "Cena não verificada"
        assert page.prepare_button.text() == "Preparar cena"
        assert page.scene_dot.state() == "idle"
        for status, (label, dot) in expected.items():
            page.load_snapshot({"scene": SCENES[status], "create": CreateSnapshot()})
            _settle(app)
            assert page.scene_status.text() == SCENES[status].status_label, status
            assert page.prepare_button.text() == label, status
            assert page.prepare_button.isVisibleTo(page), status
            assert page.prepare_button.isEnabled(), status
            assert page.scene_dot.state() == dot, status


def test_ready_scene_action_only_refreshes_instead_of_preparing_again() -> None:
    bridge = SceneBridge(SCENES["ready"])
    with _window(bridge=bridge) as (app, _window_, page, _bridge):
        page.load_snapshot({"scene": SCENES["ready"], "create": CreateSnapshot()})
        page.prepare_button.click()
        _settle(app)
        assert bridge.calls == ["refresh"]
        assert page.count_label.text() == "3 cotas"


def test_scene_card_carries_only_scene_information() -> None:
    with _window() as (_app, _window_, page, _bridge):
        assert not page.action_box.isAncestorOf(page.selection_summary)
        assert "planta" in page.selection_summary.text().lower()
        page.load_snapshot({"scene": SCENES["notPrepared"], "create": CreateSnapshot()})
        assert page.scene_detail.text() == SCENES["notPrepared"].detail
        assert page.scene_detail.isVisibleTo(page)
        # A single count is written without the "(s)" placeholder.
        page.load_snapshot({"scene": SceneSnapshot("ready", "Cena preparada", "", 1), "create": CreateSnapshot()})
        assert page.count_label.text() == "1 cota"
        assert not page.scene_detail.isVisibleTo(page)


def test_repair_that_does_not_resolve_the_scene_is_reported_honestly() -> None:
    bridge = SceneBridge(SCENES["requiresRepair"])
    unresolved = SceneSnapshot(
        "requiresRepair", "Requer reparo", "Foram encontrados múltiplos registros Ameno nesta cena."
    )
    bridge.after_prepare = unresolved
    with _window(bridge=bridge) as (app, _window_, page, _bridge):
        page.load_snapshot({"scene": SCENES["requiresRepair"], "create": CreateSnapshot()})
        page.prepare_button.click()
        _settle(app)
        assert bridge.calls == ["prepare", "refresh"]
        assert page.status.isVisibleTo(page)
        assert page.status.property("error") is True
        assert unresolved.detail in page.status.text()


def test_quoting_in_progress_locks_the_flow_and_explains_how_to_leave() -> None:
    bridge = SceneBridge(SCENES["ready"])
    observed = {}
    with _window(bridge=bridge) as (_app, _window_, page, _bridge):
        page.load_styles([StyleSnapshot("default", "Arquitetônico")])
        page.tool_choice.set_value("continuous", emit=True)

        def capture() -> None:
            observed["locked"] = [
                widget.isEnabled()
                for widget in (page.start_button, page.more_button, page.prepare_button,
                               page.tool_choice, page.plane_choice, page.mode, page.details)
            ]
            observed["status"] = page.status.text() if page.status.isVisibleTo(page) else ""
            observed["busy"] = page.start_button.text()

        bridge.during_tool = capture
        page.start_button.click()

        assert bridge.calls == ["settings", "continuous"]
        assert observed["locked"] == [False] * 7
        assert "Esc" in observed["status"]
        assert observed["busy"] == "Cotação em andamento…"
        assert page.start_button.text() == "Iniciar cotação"
        assert all(widget.isEnabled() for widget in (page.start_button, page.more_button, page.mode))
        # The busy lock must not re-enable Automática in Várias medidas.
        assert not page.mode.is_item_enabled("aligned")


def test_automatic_rule_is_explained_on_the_disabled_option_itself() -> None:
    with _window() as (_app, _window_, page, _bridge):
        automatic = page.mode._by_value["aligned"]
        page.tool_choice.set_value("continuous", emit=True)
        assert not automatic.isEnabled()
        assert "uma medida" in automatic.toolTip().lower()
        assert "uma medida" in automatic.accessibleDescription().lower()
        page.tool_choice.set_value("single", emit=True)
        assert automatic.isEnabled()
        assert "uma medida" not in automatic.toolTip().lower()


def test_primary_actions_stack_instead_of_overflowing_when_narrow() -> None:
    with _window(780, 1020) as (app, window, page, _bridge):
        start = page.start_button.mapTo(page, QtCore.QPoint(0, 0))
        more = page.more_button.mapTo(page, QtCore.QPoint(0, 0))
        assert start.y() == more.y() or abs(start.y() - more.y()) < page.start_button.height()
        assert more.x() > start.x()

        window.resize(440, 1020)
        _settle(app)
        view = window.shell.page_views["create"]
        assert view.horizontalScrollBar().maximum() == 0
        start = page.start_button.mapTo(page, QtCore.QPoint(0, 0))
        more = page.more_button.mapTo(page, QtCore.QPoint(0, 0))
        assert more.y() >= start.y() + page.start_button.height()
        assert page.more_button.width() == page.start_button.width()


def test_complete_flow_is_visible_in_the_plan_geometries_without_scene_access() -> None:
    bridge = SceneBridge()
    with _window(bridge=bridge) as (app, window, page, _bridge):
        view = window.shell.page_views["create"]
        for width, height in ((780, 1020), (780, 900), (980, 720), (780, 720), (1280, 800)):
            window.resize(width, height)
            _settle(app)
            label = "%dx%d" % (width, height)
            assert view.horizontalScrollBar().maximum() == 0, label
            for widget in (page.mode, page.action_box, page.start_button, page.more_button, page.details.toggle):
                assert _fully_visible(widget, view), (label, widget.objectName() or type(widget).__name__)
        window.resize(780, 560)
        _settle(app)
        assert view.horizontalScrollBar().maximum() == 0
        assert bridge.calls == []
