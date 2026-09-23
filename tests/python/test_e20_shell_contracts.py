"""E20.2 contracts for the adaptive shell and accessible Ameno rail."""

from __future__ import annotations

import hashlib
import os
import sys
import tempfile
from contextlib import contextmanager
from pathlib import Path
from unittest.mock import patch

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "Contents" / "python"))

from PySide6 import QtCore, QtGui, QtTest, QtWidgets  # noqa: E402

from ameno_ui.responsive import spec_for_width  # noqa: E402
from ameno_ui.theme import COLORS  # noqa: E402
from ameno_ui.window import AmenoMainWindow  # noqa: E402


NAVIGATION = (
    ("create", "Cotar"),
    ("styles", "Estilos"),
    ("edit", "Revisar"),
    ("render", "Exportar"),
    ("config", "Configurações"),
)


class LocalBridge:
    def __init__(self) -> None:
        self.calls: list[str] = []

    def cancel_interactive(self):
        self.calls.append("cancel")
        return True


@contextmanager
def _shown_window(width: int = 780, height: int = 720):
    app = QtWidgets.QApplication.instance() or QtWidgets.QApplication([])
    bridge = LocalBridge()
    with tempfile.TemporaryDirectory(prefix="ameno-e20-shell-") as directory:
        with patch.dict(os.environ, {"AMENO_SETTINGS_FILE": str(Path(directory) / "settings.ini")}):
            window = AmenoMainWindow(bridge, lambda _token: None, lambda: None)
            window.show_application("create")
            # Wider synthetic canvases intentionally exceed Qt offscreen's
            # monitor. Native-frame recovery is covered by E20.1 contracts.
            window._frame_checked = True
            window.resize(width, height)
            window.show()
            for _ in range(3):
                app.processEvents()
            try:
                yield app, window, bridge
            finally:
                window.close()
                app.sendPostedEvents(None, QtCore.QEvent.Type.DeferredDelete)
                app.processEvents()


def _image_digest(widget: QtWidgets.QWidget) -> str:
    image = widget.grab().toImage().convertToFormat(QtGui.QImage.Format.Format_RGBA8888)
    return hashlib.sha256(image.bits().tobytes()).hexdigest()


def _relative_luminance(color: str) -> float:
    rgb = QtGui.QColor(color)
    assert rgb.isValid(), color
    channels = []
    for value in (rgb.redF(), rgb.greenF(), rgb.blueF()):
        channels.append(value / 12.92 if value <= 0.04045 else ((value + 0.055) / 1.055) ** 2.4)
    return 0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2]


def _contrast_ratio(first: str, second: str) -> float:
    lighter, darker = sorted((_relative_luminance(first), _relative_luminance(second)), reverse=True)
    return (lighter + 0.05) / (darker + 0.05)


def test_responsive_mode_is_derived_from_the_page_viewport_width() -> None:
    """The rail must not classify the shell from the outer window width."""

    with _shown_window() as (app, window, _bridge):
        for width, height in ((780, 1020), (980, 720), (1280, 800), (1560, 900)):
            window.resize(width, height)
            for _ in range(3):
                app.processEvents()
            viewport_width = window.shell.page_views["create"].viewport().width()
            assert window.shell._responsive_mode == spec_for_width(viewport_width).mode, (
                width,
                viewport_width,
                window.shell._responsive_mode,
                spec_for_width(viewport_width).mode,
            )


def test_resize_and_navigation_keep_pages_views_and_connections_stable() -> None:
    with _shown_window() as (app, window, bridge):
        page_ids = {key: id(value) for key, value in window.shell.pages.items()}
        view_ids = {key: id(value) for key, value in window.shell.page_views.items()}
        widget_count = len(window.shell.findChildren(QtWidgets.QWidget))
        dispatched: list[str] = []
        show_page = window.shell.show_page

        def observed(name: str, refresh: bool = False) -> None:
            dispatched.append(name)
            show_page(name, refresh)

        window.shell.show_page = observed
        expected: list[str] = []
        for index in range(40):
            width, height = ((780, 1020), (980, 720), (1280, 800), (1560, 900))[index % 4]
            key = NAVIGATION[index % len(NAVIGATION)][0]
            window.resize(width, height)
            app.processEvents()
            window.shell._nav_by_key[key].click()
            app.processEvents()
            expected.append(key)

        assert dispatched == expected
        assert {key: id(value) for key, value in window.shell.pages.items()} == page_ids
        assert {key: id(value) for key, value in window.shell.page_views.items()} == view_ids
        assert len(window.shell.findChildren(QtWidgets.QWidget)) == widget_count
        assert bridge.calls == []


def test_every_page_stays_within_its_viewport_without_horizontal_scrolling() -> None:
    with _shown_window() as (app, window, _bridge):
        for width, height in ((520, 700), (780, 1020), (980, 720), (1280, 800), (1560, 900)):
            window.resize(width, height)
            for key, view in window.shell.page_views.items():
                window.shell.show_page(key)
                for _ in range(2):
                    app.processEvents()
                assert view.horizontalScrollBar().maximum() == 0, (key, width, height)
                assert view.widget().width() <= view.viewport().width(), (key, width, height)
                assert view.widget().minimumWidth() <= view.viewport().width(), (key, width, height)
                if key == "styles":
                    controls = window.shell.pages[key].controls_scroll
                    assert controls.horizontalScrollBar().maximum() == 0, (key, width, height, "controls")


def test_rail_keeps_the_approved_order_and_semantic_labels() -> None:
    with _shown_window() as (_app, window, _bridge):
        assert tuple(window.shell._nav_by_key) == tuple(key for key, _label in NAVIGATION)
        top_positions = []
        for key, label in NAVIGATION:
            button = window.shell._nav_by_key[key]
            assert button.accessibleName() == label
            assert button.toolTip() == label
            assert not button.icon().isNull()
            if key != "config":
                top_positions.append(button.mapTo(window.shell.sidebar, QtCore.QPoint()).y())
        assert top_positions == sorted(top_positions)
        assert window.shell.help_button.accessibleName() == "Ajuda"
        assert window.shell.help_button.toolTip() == "Como começar"
        assert not window.shell.help_button.icon().isNull()
        assert window.shell.help_button.y() < window.shell._nav_by_key["config"].y()


def test_compact_rail_actions_have_at_least_a_44px_target() -> None:
    with _shown_window(780, 1020) as (_app, window, _bridge):
        assert window.shell._responsive_mode == "compact"
        actions = list(window.shell._nav_by_key.values()) + [window.shell.help_button]
        for action in actions:
            assert action.isVisible()
            assert action.width() >= 44 and action.height() >= 44, (
                action.accessibleName(),
                action.size().toTuple(),
            )


def test_keyboard_focus_is_visible_on_the_compact_rail() -> None:
    with _shown_window(780, 1020) as (app, window, _bridge):
        button = window.shell._nav_by_key["styles"]
        window.shell._nav_by_key["create"].setFocus()
        app.processEvents()
        unfocused = _image_digest(button)
        button.setFocus(QtCore.Qt.FocusReason.TabFocusReason)
        app.processEvents()
        assert button.hasFocus()
        assert _image_digest(button) != unfocused


def test_keyboard_can_activate_every_page_from_the_rail() -> None:
    with _shown_window(780, 1020) as (app, window, _bridge):
        for key, _label in NAVIGATION:
            button = window.shell._nav_by_key[key]
            button.setFocus(QtCore.Qt.FocusReason.TabFocusReason)
            QtTest.QTest.keyClick(button, QtCore.Qt.Key.Key_Space)
            app.processEvents()
            assert window.shell.content.currentWidget() is window.shell.page_views[key]
            assert button.isChecked()


def test_core_color_tokens_meet_text_and_focus_contrast_thresholds() -> None:
    pairs = (
        ("text", "background", 4.5),
        ("text", "secondary", 4.5),
        ("muted", "background", 4.5),
        ("disabled", "background", 3.0),
        ("red", "background", 3.0),
        ("red", "secondary", 3.0),
    )
    for foreground, background, minimum in pairs:
        ratio = _contrast_ratio(COLORS[foreground], COLORS[background])
        assert ratio >= minimum, (foreground, background, ratio, minimum)
    # Primary actions use dark ink on Ameno red.
    assert _contrast_ratio("#090909", COLORS["red"]) >= 4.5
