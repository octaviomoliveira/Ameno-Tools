"""E18.1 contracts for the scene-independent StyleDraft."""

from __future__ import annotations

import os
import sys
from pathlib import Path

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "Contents" / "python"))

from PySide6 import QtWidgets  # noqa: E402

from ameno_ui.models import StyleSnapshot  # noqa: E402
from ameno_ui.style_draft import StyleDraft  # noqa: E402


def _app() -> QtWidgets.QApplication:
    return QtWidgets.QApplication.instance() or QtWidgets.QApplication([])


def test_draft_is_valid_and_clean_before_any_style_library_read() -> None:
    _app()
    draft = StyleDraft()
    snapshot = draft.to_snapshot()
    assert isinstance(snapshot, StyleSnapshot)
    assert snapshot.style_id == "default"
    assert snapshot.name == "Arquitetônico"
    assert not draft.dirty


def test_draft_normalizes_decimal_enum_and_bounds_without_external_calls() -> None:
    _app()
    draft = StyleDraft()
    changed = []
    draft.changed.connect(lambda field, value: changed.append((field, value)))
    draft.set("font_size", "1,25")
    draft.set("tracking", "-999")
    draft.set("terminal_type", "not-a-terminal")
    draft.set("terminal_angle", "999")
    assert draft.value("font_size") == 1.25
    assert draft.value("tracking") == -100.0
    assert draft.value("terminal_type") == "tick"
    assert draft.value("terminal_angle") == 180.0
    assert len(changed) == 3


def test_draft_dirty_clean_and_restore_are_explicit() -> None:
    _app()
    draft = StyleDraft(StyleSnapshot("s", "Teste", font_size=140.0))
    dirty_states = []
    draft.dirty_changed.connect(dirty_states.append)
    draft.set("font_size", 200)
    assert draft.dirty
    assert dirty_states == [True]
    draft.mark_clean()
    assert not draft.dirty
    draft.set("font_size", 280)
    draft.restore_clean()
    assert draft.value("font_size") == 200.0
    assert dirty_states == [True, False, True, False]


def test_draft_load_is_atomic_and_snapshot_contains_every_style_field() -> None:
    _app()
    original = StyleSnapshot("s", "Teste", font_name="Space Grotesk", tracking=12.5, terminal_type="dot")
    draft = StyleDraft()
    draft.set("font_size", 300)
    draft.load(original)
    assert not draft.dirty
    assert draft.to_snapshot() == original
    assert set(draft._FIELD_NAMES) == {field.name for field in __import__("dataclasses").fields(StyleSnapshot)}
