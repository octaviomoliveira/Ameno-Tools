"""E19 acceptance contracts for the Cotar reference layout."""

from __future__ import annotations

import os
import sys
import tempfile
from pathlib import Path

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "Contents" / "python"))

from PySide6 import QtCore, QtWidgets  # noqa: E402

from ameno_ui.components import ChoiceCard, SegmentedChoice  # noqa: E402
from ameno_ui.window import AmenoMainWindow  # noqa: E402


class ReferenceBridge:
    def cancel_interactive(self):
        return True


def _app() -> QtWidgets.QApplication:
    return QtWidgets.QApplication.instance() or QtWidgets.QApplication([])


def _wrapped_text_fits(label: QtWidgets.QLabel) -> bool:
    available = label.contentsRect()
    required = label.fontMetrics().boundingRect(
        QtCore.QRect(0, 0, max(1, available.width()), 2000),
        int(QtCore.Qt.TextFlag.TextWordWrap),
        label.text(),
    )
    return required.height() <= available.height()


def test_cotar_matches_reference_contract_at_980x720() -> None:
    app = _app()
    os.environ["AMENO_SETTINGS_FILE"] = str(Path(tempfile.mkdtemp()) / "e19-cotar.ini")
    window = AmenoMainWindow(ReferenceBridge(), lambda _token: None, lambda: None)
    window.resize(980, 720)
    window.show_application("create")
    window.show()
    app.processEvents()

    page = window.shell.pages["create"]
    view = window.shell.page_views["create"]
    cards = page.findChildren(ChoiceCard)
    assert len(cards) == 4
    assert window.shell.sidebar.width() <= 184
    assert view.horizontalScrollBar().maximum() == 0
    assert all(len(card.hint_label.text()) <= 34 for card in cards)
    assert all(card.title_label.wordWrap() and card.hint_label.wordWrap() for card in cards)
    assert all(_wrapped_text_fits(card.title_label) for card in cards)
    assert all(_wrapped_text_fits(card.hint_label) for card in cards)

    cta_pos = page.start_button.mapTo(view.viewport(), QtCore.QPoint(0, 0))
    assert cta_pos.y() >= 0
    assert cta_pos.y() + page.start_button.height() <= view.viewport().height()
    window.close()
    app.processEvents()


def test_choice_cards_keep_one_active_option_per_question() -> None:
    _app()
    window = AmenoMainWindow(ReferenceBridge(), lambda _token: None, lambda: None)
    page = window.shell.pages["create"]
    page.tool_choice.set_value("continuous", emit=True)
    page.plane_choice.set_value("viewPlane", emit=True)
    assert page.tool_choice.value() == "continuous"
    assert page.plane_choice.value() == "viewPlane"
    assert sum(card.isChecked() for card in page.tool_choice.findChildren(ChoiceCard)) == 1
    assert sum(card.isChecked() for card in page.plane_choice.findChildren(ChoiceCard)) == 1
    window.close()


def test_continuous_measurement_prevents_automatic_direction_in_the_main_flow() -> None:
    _app()
    os.environ["AMENO_SETTINGS_FILE"] = str(Path(tempfile.mkdtemp()) / "e19-direction.ini")
    window = AmenoMainWindow(ReferenceBridge(), lambda _token: None, lambda: None)
    page = window.shell.pages["create"]
    assert isinstance(page.mode, SegmentedChoice)
    page.tool_choice.set_value("single", emit=True)
    page.mode.set_value("aligned", emit=True)

    page.tool_choice.set_value("continuous", emit=True)

    assert page.mode.currentData() == "horizontal"
    assert not page.mode.is_item_enabled("aligned")
    assert not page.direction_message.isHidden()
    assert page.direction_message.text() == (
        "Direção alterada para Horizontal · Automática só funciona em uma medida."
    )

    page.mode.set_value("vertical", emit=True)
    assert page.mode.currentData() == "vertical"
    assert page.direction_message.text() == (
        "Em várias medidas, a direção automática não está disponível."
    )

    page.tool_choice.set_value("single", emit=True)
    assert page.mode.is_item_enabled("aligned")
    assert page.direction_message.isHidden()
    page.mode.set_value("vertical", emit=True)
    page.tool_choice.set_value("continuous", emit=True)
    assert page.mode.currentData() == "horizontal"
    assert page.direction_message.text() == (
        "Em várias medidas, a direção automática não está disponível."
    )
    window.close()


def test_invalid_direction_modal_is_only_a_start_fallback() -> None:
    _app()
    os.environ["AMENO_SETTINGS_FILE"] = str(Path(tempfile.mkdtemp()) / "e19-fallback.ini")
    window = AmenoMainWindow(ReferenceBridge(), lambda _token: None, lambda: None)
    page = window.shell.pages["create"]
    page.tool_choice.set_value("continuous", emit=True)
    automatic = page.mode._by_value["aligned"]
    automatic.setEnabled(True)
    automatic.setChecked(True)
    automatic.setEnabled(False)
    calls = []
    original = QtWidgets.QMessageBox.warning
    QtWidgets.QMessageBox.warning = lambda *args: calls.append(args)  # type: ignore[assignment]
    try:
        page.start_selected()
    finally:
        QtWidgets.QMessageBox.warning = original  # type: ignore[assignment]
    assert len(calls) == 1
    assert page.mode.currentData() == "horizontal"
    window.close()


def test_direction_segments_use_local_reference_icons() -> None:
    _app()
    os.environ["AMENO_SETTINGS_FILE"] = str(Path(tempfile.mkdtemp()) / "e19-icons.ini")
    icon_root = ROOT / "Contents" / "python" / "ameno_ui" / "assets" / "icons"
    for name in ("direcao-automatica.svg", "direcao-horizontal.svg", "direcao-vertical.svg"):
        source = icon_root / name
        assert source.is_file()
        assert "<svg" in source.read_text(encoding="utf-8")
    window = AmenoMainWindow(ReferenceBridge(), lambda _token: None, lambda: None)
    buttons = window.shell.pages["create"].mode.buttons.buttons()
    assert len(buttons) == 3
    assert all(not widget.icon().isNull() for widget in buttons)
    window.close()


def test_automatic_direction_recovers_after_silent_single_selection_and_show() -> None:
    app = _app()
    os.environ["AMENO_SETTINGS_FILE"] = str(Path(tempfile.mkdtemp()) / "e19-auto-recovery.ini")
    window = AmenoMainWindow(ReferenceBridge(), lambda _token: None, lambda: None)
    page = window.shell.pages["create"]
    page.tool_choice.set_value("continuous")
    assert not page.mode.is_item_enabled("aligned")
    page.tool_choice.set_value("single")
    assert page.mode.is_item_enabled("aligned")

    page.mode.set_item_enabled("aligned", False)
    window.show_application("create")
    window.show()
    app.processEvents()
    assert page.tool_choice.value() == "single"
    assert page.mode.is_item_enabled("aligned")
    page.mode._by_value["aligned"].click()
    assert page.mode.currentData() == "aligned"
    window.close()
    app.processEvents()
