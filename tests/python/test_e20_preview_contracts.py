"""E20.0 RED contracts for a preview faithful to committed dimensions.

The dimensional ratios below come from the production MAXScript geometry,
not from the existing Python painter. They are independent of canvas size,
scene unit, camera scale, and antialiasing. The E20.4 implementation must make
these tests green without changing the cotation backend to match the preview.

Oracles:
* core/ameno_dimension_terminal_mesh.ms::createTerminal: closed arrow base
  width = size * 0.5, dot radius = size * 0.35, diamond diagonals = size.
* core/ameno_dimension_graphics.ms::addTerminals: open arrow base width =
  size * 0.5, arrows parallel to the dimension, tick length = size.
* core/ameno_dimension_graphics.ms::createLineNode/configureLineShape:
  gap, overhang, terminal size and line thickness share one mm conversion.

Wall reference dots are architectural guides, not dimension terminals; none
of these contracts mistakes those guide dots for a faulty terminal.
"""

from __future__ import annotations

import sys
from dataclasses import replace
from math import hypot, isclose, isfinite
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "Contents" / "python"))

from ameno_ui.dimension_preview import build_preview_geometry  # noqa: E402
from ameno_ui.models import StyleSnapshot  # noqa: E402


def _distance(first, second) -> float:
    return hypot(second[0] - first[0], second[1] - first[1])


def _assert_ratio(actual: float, expected: float, description: str) -> None:
    assert isclose(actual, expected, rel_tol=1e-6, abs_tol=1e-6), (
        "%s: preview %.6f, required ratio %.6f"
        % (description, actual, expected)
    )


def _arrow_base(terminal):
    if terminal.kind == "arrowOpen":
        return terminal.points[1], terminal.points[3]
    return terminal.points[1], terminal.points[2]


def test_closed_arrow_has_the_committed_half_width_to_length_ratio() -> None:
    style = StyleSnapshot("technical", "Technical", terminal_type="arrowClosed", terminal_angle=0)
    geometry = build_preview_geometry(style, (620, 240))
    for terminal in geometry.terminals:
        base_a, base_b = _arrow_base(terminal)
        base_center = ((base_a[0] + base_b[0]) / 2, (base_a[1] + base_b[1]) / 2)
        _assert_ratio(
            _distance(base_a, base_b) / _distance(terminal.anchor, base_center),
            0.5,
            "closed arrow base width / axial length",
        )


def test_open_arrow_has_the_committed_half_width_to_length_ratio() -> None:
    style = StyleSnapshot("open", "Open", terminal_type="arrowOpen", terminal_angle=0)
    geometry = build_preview_geometry(style, (620, 240))
    for terminal in geometry.terminals:
        base_a, base_b = _arrow_base(terminal)
        base_center = ((base_a[0] + base_b[0]) / 2, (base_a[1] + base_b[1]) / 2)
        _assert_ratio(
            _distance(base_a, base_b) / _distance(terminal.anchor, base_center),
            0.5,
            "open arrow base width / axial length",
        )


def test_default_arrows_stay_parallel_to_the_committed_dimension_line() -> None:
    # The technical preset carries terminal_angle=45, but the committed arrow
    # is aligned to layout.direction. Applying that tick angle to an arrow
    # currently tilts both preview heads away from the real dimension.
    for kind in ("arrowClosed", "arrowOpen"):
        geometry = build_preview_geometry(
            StyleSnapshot("technical", "Technical", terminal_type=kind),
            (620, 240),
        )
        for terminal in geometry.terminals:
            base_a, base_b = _arrow_base(terminal)
            base_center_y = (base_a[1] + base_b[1]) / 2
            assert isclose(base_center_y, terminal.anchor[1], abs_tol=1e-6), (
                "%s is tilted in preview: base center y=%.6f, line y=%.6f"
                % (kind, base_center_y, terminal.anchor[1])
            )


def test_dot_radius_matches_the_committed_fraction_of_terminal_size() -> None:
    style = StyleSnapshot("s", "Sample", terminal_size=200)
    tick = build_preview_geometry(style, (620, 240)).terminals[0]
    dot = build_preview_geometry(replace(style, terminal_type="dot"), (620, 240)).terminals[0]
    _assert_ratio(dot.radius / _distance(*tick.points), 0.35, "dot radius / terminal size")


def test_backend_supported_diamond_is_a_centered_four_vertex_terminal() -> None:
    style = StyleSnapshot("diamond", "Diamond", terminal_type="diamond", terminal_size=200)
    geometry = build_preview_geometry(style, (620, 240))
    for terminal in geometry.terminals:
        assert len(terminal.points) == 4, (
            "committed diamond has four vertices; preview has %d" % len(terminal.points)
        )
        centroid = tuple(sum(point[axis] for point in terminal.points) / 4 for axis in (0, 1))
        assert _distance(centroid, terminal.anchor) < 1e-6, "diamond must be centered on the endpoint"
        _assert_ratio(
            _distance(terminal.points[0], terminal.points[2])
            / _distance(terminal.points[1], terminal.points[3]),
            1.0,
            "diamond diagonal ratio",
        )


def test_equal_physical_terminal_gap_and_overhang_use_one_canvas_scale() -> None:
    style = StyleSnapshot(
        "equal", "Equal dimensions", terminal_size=100, extension_gap=100, extension_overhang=100,
    )
    geometry = build_preview_geometry(style, (620, 240))
    tick_length = _distance(*geometry.terminals[0].points)
    dimension_y = geometry.dimension_segment.start[1]
    extension = geometry.extension_segments[0]
    wall_y = geometry.wall_reference_points[0][1]
    overhang = dimension_y - min(extension.start[1], extension.end[1])
    gap = wall_y - max(extension.start[1], extension.end[1])
    _assert_ratio(overhang / tick_length, 1.0, "100 mm overhang / 100 mm terminal")
    _assert_ratio(gap / tick_length, 1.0, "100 mm gap / 100 mm terminal")


def test_line_thickness_and_terminal_length_preserve_the_physical_ratio() -> None:
    style = StyleSnapshot("physical", "Physical ratios", terminal_size=100, line_thickness=10)
    geometry = build_preview_geometry(style, (620, 240))
    tick_length = _distance(*geometry.terminals[0].points)
    _assert_ratio(
        geometry.line_thickness_px / tick_length,
        style.line_thickness / style.terminal_size,
        "10 mm line thickness / 100 mm terminal",
    )


def test_zoom_preserves_terminal_to_measured_span_ratio() -> None:
    # Zoom is a view operation; it must not change the proportions of a style
    # relative to the same 3.50 m sample. A fit transform may change global
    # scale, but must apply the same scale to all geometry.
    style = StyleSnapshot("zoom", "Zoom", terminal_size=200)
    ratios = []
    for zoom in (0.5, 1.0):
        geometry = build_preview_geometry(style, (620, 240), zoom=zoom)
        ratios.append(
            _distance(*geometry.terminals[0].points)
            / _distance(geometry.dimension_segment.start, geometry.dimension_segment.end)
        )
    _assert_ratio(ratios[0], ratios[1], "terminal / measured span at 50% versus 100% zoom")


def test_extreme_supported_text_settings_fit_the_preview_canvas() -> None:
    # Both are legal values in style_parameter_specs(). The complete label
    # must remain understandable rather than being silently painted above
    # the widget. The bounds here are the model's own text mask, not a
    # screenshot/font substitution artifact.
    style = StyleSnapshot("large", "Large annotation", font_size=5000, text_gap=1000)
    geometry = build_preview_geometry(style, (620, 240))
    assert geometry.text.mask_rect is not None
    x, y, width, height = geometry.text.mask_rect
    assert all(isfinite(value) for value in (x, y, width, height))
    assert 0 <= x and 0 <= y and x + width <= geometry.width and y + height <= geometry.height, (
        "text mask %r falls outside %.0fx%.0f preview"
        % (geometry.text.mask_rect, geometry.width, geometry.height)
    )
