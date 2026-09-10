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

from ameno_ui.components import ChoiceCard  # noqa: E402
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
