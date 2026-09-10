"""E18.3 pure preview geometry contracts."""

from __future__ import annotations

import os
import sys
from dataclasses import replace
from pathlib import Path

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "Contents" / "python"))

from ameno_ui.dimension_preview import build_preview_geometry  # noqa: E402
from ameno_ui.models import StyleSnapshot  # noqa: E402


def _style() -> StyleSnapshot:
    return StyleSnapshot("s", "Teste")


def test_geometry_is_deterministic_and_does_not_require_qt_or_scene() -> None:
    style = _style()
    first = build_preview_geometry(style, (620, 240))
    second = build_preview_geometry(style, (620, 240))
    assert first == second
    assert first.width == 620.0
    assert first.height == 240.0
    assert len(first.extension_segments) == 2
    assert first.dimension_segment.start[0] < first.dimension_segment.end[0]


def test_line_and_text_parameters_have_visible_geometry_effects() -> None:
    base = build_preview_geometry(_style(), (620, 240))
    thick = build_preview_geometry(replace(_style(), line_thickness=8), (620, 240))
    text = build_preview_geometry(replace(_style(), font_size=420, tracking=40, text_gap=220), (620, 240))
    no_mask = build_preview_geometry(replace(_style(), text_mask_enabled=False), (620, 240))
    assert thick.line_thickness_px != base.line_thickness_px
    assert thick.dimension_segment == base.dimension_segment
    assert text.text.font_size_px != base.text.font_size_px
    assert text.text.tracking_px != base.text.tracking_px
    assert text.text.baseline != base.text.baseline
    assert base.text.mask_rect is not None
    assert no_mask.text.mask_rect is None


def test_extension_and_scale_parameters_move_preview_primitives() -> None:
    base = build_preview_geometry(_style(), (620, 240))
    extended = build_preview_geometry(
        replace(_style(), extension_overhang=300, extension_gap=120, preview_scale=2.0),
        (620, 240),
    )
    assert extended.effective_scale != base.effective_scale
    assert extended.extension_segments != base.extension_segments
    assert extended.dimension_segment != base.dimension_segment


def test_terminal_type_size_placement_and_angle_are_not_decorative() -> None:
    base = build_preview_geometry(_style(), (620, 240))
    arrow = build_preview_geometry(
        replace(_style(), terminal_type="arrowClosed", terminal_size=260, terminal_placement="outside", terminal_angle=90),
        (620, 240),
    )
    none = build_preview_geometry(replace(_style(), terminal_type="none"), (620, 240))
    assert [item.kind for item in base.terminals] == ["tick", "tick"]
    assert [item.kind for item in arrow.terminals] == ["arrowClosed", "arrowClosed"]
    assert arrow.terminals != base.terminals
    assert all(item.kind == "none" and not item.points for item in none.terminals)


def test_text_color_is_separate_from_line_color() -> None:
    geometry = build_preview_geometry(
        replace(_style(), annotation_color="10,20,30", text_color="200,210,220"),
        (620, 240),
    )
    assert geometry.line_color == "10,20,30"
    assert geometry.text.color == "200,210,220"
