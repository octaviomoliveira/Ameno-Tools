"""Pure geometry model for the local 2D dimension preview."""

from __future__ import annotations

from dataclasses import dataclass
from math import cos, radians, sin
from typing import Any, Iterable, Tuple

from .models import StyleSnapshot


Point = Tuple[float, float]


@dataclass(frozen=True)
class PreviewSegment:
    start: Point
    end: Point


@dataclass(frozen=True)
class PreviewTerminal:
    kind: str
    anchor: Point
    points: tuple[Point, ...] = ()
    radius: float = 0.0


@dataclass(frozen=True)
class PreviewText:
    value: str
    baseline: Point
    font_name: str
    font_size_px: float
    tracking_px: float
    bold: bool
    italic: bool
    color: str
    mask_rect: tuple[float, float, float, float] | None


@dataclass(frozen=True)
class PreviewGeometry:
    width: float
    height: float
    line_color: str
    line_thickness_px: float
    extension_segments: tuple[PreviewSegment, ...]
    dimension_segment: PreviewSegment
    terminals: tuple[PreviewTerminal, ...]
    text: PreviewText
    effective_scale: float

    @property
    def all_segments(self) -> tuple[PreviewSegment, ...]:
        return self.extension_segments + (self.dimension_segment,)


def _rect_size(viewport_rect: Any) -> tuple[float, float]:
    if hasattr(viewport_rect, "width") and hasattr(viewport_rect, "height"):
        return max(1.0, float(viewport_rect.width())), max(1.0, float(viewport_rect.height()))
    if isinstance(viewport_rect, (tuple, list)) and len(viewport_rect) >= 2:
        return max(1.0, float(viewport_rect[0])), max(1.0, float(viewport_rect[1]))
    raise TypeError("viewport_rect deve ser (largura, altura) ou QRectF")


def _color_text(value: str, fallback: str = "245,245,245") -> str:
    parts = str(value or "").split(",")
    if len(parts) != 3:
        return fallback
    try:
        channels = [max(0, min(255, int(part.strip()))) for part in parts]
    except (TypeError, ValueError):
        return fallback
    return ",".join(str(channel) for channel in channels)


def _add(point: Point, vector: Point) -> Point:
    return point[0] + vector[0], point[1] + vector[1]


def _sub(point: Point, vector: Point) -> Point:
    return point[0] - vector[0], point[1] - vector[1]


def _scale(vector: Point, amount: float) -> Point:
    return vector[0] * amount, vector[1] * amount


def _terminal(kind: str, anchor: Point, size: float, angle: float, side: float) -> PreviewTerminal:
    if kind == "none":
        return PreviewTerminal(kind, anchor)
    theta = radians(angle)
    axis = (cos(theta) * side, sin(theta) * side)
    normal = (-axis[1], axis[0])
    if kind == "dot":
        return PreviewTerminal(kind, anchor, radius=max(2.0, size * 0.16))
    if kind == "tick":
        return PreviewTerminal(kind, anchor, points=(anchor, _add(anchor, _scale(axis, size))))
    if kind == "arrowOpen":
        tip = anchor
        back = _sub(anchor, _scale(axis, size))
        arm = _scale(normal, size * 0.42)
        return PreviewTerminal(kind, anchor, points=(tip, _add(back, arm), tip, _sub(back, arm)))
    # arrowClosed and unknown values are represented as a filled triangular head.
    back = _sub(anchor, _scale(axis, size))
    half = _scale(normal, size * 0.45)
    return PreviewTerminal(kind, anchor, points=(anchor, _add(back, half), _sub(back, half)))


def build_preview_geometry(
    snapshot: StyleSnapshot,
    viewport_rect: Any,
    zoom: float = 1.0,
    text: str = "3,50 m",
) -> PreviewGeometry:
    """Build all preview primitives without importing Qt or touching the scene."""

    width, height = _rect_size(viewport_rect)
    external_zoom = max(0.25, min(4.0, float(zoom or 1.0)))
    style_scale = max(0.1, min(10.0, float(snapshot.preview_scale or 1.0)))
    effective_scale = external_zoom * style_scale
    margin = max(18.0, min(64.0, width * 0.08))
    left_anchor = margin
    right_anchor = max(left_anchor + 60.0, width - margin)
    center_y = height * 0.62

    # Keep the preview legible while still exposing the physical style values.
    feature_scale = max(0.08, min(0.8, min(width / 900.0, height / 300.0))) * effective_scale
    extension_gap = max(0.0, float(snapshot.extension_gap)) * 0.15 * feature_scale
    overhang = max(0.0, float(snapshot.extension_overhang)) * 0.12 * feature_scale
    terminal_size = max(4.0, float(snapshot.terminal_size) * 0.08 * feature_scale)
    line_thickness = max(0.5, float(snapshot.line_thickness) * 0.75 * feature_scale)

    left = left_anchor + extension_gap
    right = right_anchor - extension_gap
    if right <= left + 20:
        left, right = left_anchor, right_anchor
    extension_top = max(8.0, center_y - (34.0 + overhang))
    extension_bottom = min(height - 8.0, center_y + (34.0 + overhang))
    extension_segments = (
        PreviewSegment((left, extension_top), (left, extension_bottom)),
        PreviewSegment((right, extension_top), (right, extension_bottom)),
    )
    dimension_segment = PreviewSegment((left, center_y), (right, center_y))

    placement = str(snapshot.terminal_placement or "auto")
    placement_offset = terminal_size * 0.25
    if placement == "inside":
        left_terminal_anchor = (left + placement_offset, center_y)
        right_terminal_anchor = (right - placement_offset, center_y)
    elif placement == "outside":
        left_terminal_anchor = (left - placement_offset, center_y)
        right_terminal_anchor = (right + placement_offset, center_y)
    else:
        left_terminal_anchor = (left, center_y)
        right_terminal_anchor = (right, center_y)
    terminal_kind = str(snapshot.terminal_type or "tick")
    terminal_angle = float(snapshot.terminal_angle or 0.0)
    terminals = (
        _terminal(terminal_kind, left_terminal_anchor, terminal_size, terminal_angle, 1.0),
        _terminal(terminal_kind, right_terminal_anchor, terminal_size, terminal_angle, -1.0),
    )

    font_size_px = max(8.0, min(120.0, float(snapshot.font_size) * 0.16 * feature_scale))
    tracking_px = float(snapshot.tracking) * 0.08 * feature_scale
    text_width = max(font_size_px * 1.8, len(text) * font_size_px * 0.56 + max(0, len(text) - 1) * tracking_px)
    text_gap = max(8.0, float(snapshot.text_gap) * 0.12 * feature_scale)
    text_baseline = ((left + right) * 0.5 - text_width * 0.5, center_y - text_gap)
    mask_padding = max(4.0, font_size_px * 0.14)
    mask_rect = (
        text_baseline[0] - mask_padding,
        text_baseline[1] - font_size_px - mask_padding,
        text_width + 2 * mask_padding,
        font_size_px + 2 * mask_padding,
    ) if snapshot.text_mask_enabled else None
    text_color = _color_text(snapshot.text_color or snapshot.annotation_color)
    preview_text = PreviewText(
        value=text,
        baseline=text_baseline,
        font_name=str(snapshot.font_name or "Arial"),
        font_size_px=font_size_px,
        tracking_px=tracking_px,
        bold=bool(snapshot.bold),
        italic=bool(snapshot.italic),
        color=text_color,
        mask_rect=mask_rect,
    )
    return PreviewGeometry(
        width=width,
        height=height,
        line_color=_color_text(snapshot.annotation_color),
        line_thickness_px=line_thickness,
        extension_segments=extension_segments,
        dimension_segment=dimension_segment,
        terminals=terminals,
        text=preview_text,
        effective_scale=effective_scale,
    )
