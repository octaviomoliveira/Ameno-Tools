"""Headless Qt smoke test for the presentation layer (no 3ds Max scene)."""

from __future__ import annotations

import os
import sys
from types import SimpleNamespace

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "Contents", "python"))

from PySide6.QtGui import QImage  # noqa: E402
from PySide6.QtWidgets import QApplication  # noqa: E402

from ameno_ui.models import AuditSnapshot, CreateSnapshot, SceneSnapshot, StyleSnapshot  # noqa: E402
from ameno_ui.application import AmenoApplication  # noqa: E402
from ameno_ui.styles_page import PreviewWidget  # noqa: E402
from ameno_ui.window import AmenoMainWindow  # noqa: E402


class FakeBridge:
    def __init__(self) -> None:
        self.calls = []

    def cancel_interactive(self):
        self.calls.append("cancel")
        return True

    def scene(self):
        self.calls.append("scene")
        return SceneSnapshot(renderer_label="Arnold", renderer_state="sem adapter")

    def default_render_path(self):
        self.calls.append("default_render_path")
        return "C:/temp/cotas.png"


def test_window_builds_and_navigation_stays_local() -> None:
    app = QApplication.instance() or QApplication([])
    bridge = FakeBridge()
    window = AmenoMainWindow(bridge, lambda _token: None, lambda: None)
    assert window.stack.currentWidget() is window.login_page
    assert bridge.calls == []

    style = StyleSnapshot("default", "Arquitetônico")
    window.shell.pages["create"].load_styles([style])
    window.shell.pages["create"].load_snapshot({"scene": SceneSnapshot(dimension_count=2), "create": CreateSnapshot()})
    window.shell.pages["styles"].load_styles([style])
    window.shell.pages["edit"]._load(
        AuditSnapshot("dim", "measured", 100.0, 100.0, 0.0, "100 mm", "100 mm", "0 mm", "", False, "world", "Mundial", False, "")
    )

    for page in ("create", "styles", "edit", "render", "config"):
        window.shell.show_page(page)
    assert bridge.calls == []

    window.shell.pages["render"].refresh()
    assert bridge.calls == ["scene", "default_render_path"]
    window.show_application("create")
    window.close()
    app.processEvents()
    assert bridge.calls[-1] == "cancel"


def test_preview_paints_without_scene_objects() -> None:
    app = QApplication.instance() or QApplication([])
    preview = PreviewWidget()
    preview.resize(420, 190)
    preview.set_model(StyleSnapshot("default", "Arquitetônico", annotation_color="10,20,30"), True, 1.0)
    image = QImage(420, 190, QImage.Format.Format_ARGB32)
    image.fill(0)
    preview.render(image)
    assert not image.isNull()
    app.processEvents()


def test_login_enters_app_without_blocking_on_scene_refresh() -> None:
    app = QApplication.instance() or QApplication([])

    class GuardBridge:
        def refresh(self):
            raise AssertionError("login não pode atualizar a cena de forma síncrona")

    class FakeStatus:
        def __init__(self) -> None:
            self.text = ""

        def setText(self, value: str) -> None:  # noqa: N802 - Qt-like fake
            self.text = value

    class FakeWindow:
        def __init__(self) -> None:
            self.calls = []
            self.shell = SimpleNamespace(pages={"create": SimpleNamespace(status=FakeStatus())})

        def set_authenticating(self, busy: bool) -> None:
            self.calls.append(("busy", busy))

        def report_login(self, message: str, error: bool = False) -> None:
            self.calls.append(("login", message, error))

        def show_application(self, page: str) -> None:
            self.calls.append(("show", page))

    coordinator = AmenoApplication()
    coordinator.bridge = GuardBridge()
    coordinator.window = FakeWindow()
    coordinator.authenticate("E15-TESTE")

    assert coordinator.auth.authenticated
    assert ("show", "create") in coordinator.window.calls
    assert coordinator.window.shell.pages["create"].status.text.startswith("Sessão aberta")
    app.processEvents()
