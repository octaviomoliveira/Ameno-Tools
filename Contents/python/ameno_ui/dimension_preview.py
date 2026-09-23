"""Pure geometry model for the local 2D dimension preview."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any, Tuple

from .models import StyleSnapshot


Point = Tuple[float, float]


@dataclass(frozen=True)
class PreviewSegment:
    start: Point
    end: Point


@dataclass(frozen=True)
class PreviewRect:
    x: float
    y: float
    width: float
    height: float


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
    wall_rects: tuple[PreviewRect, ...]
    wall_reference_points: tuple[Point, ...]
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


# Physical sample, in millimetres, around which the style is drawn. The
# measured span matches its label; the wall only gives context. Narrow or tall
# canvases measure a shorter wall so text and terminals stay legible.
SAMPLE_SPAN_MM = 3500.0
MIN_SAMPLE_SPAN_MM = 1200.0
SAMPLE_OFFSET_MM = 600.0
WALL_THICKNESS_MM = 150.0
WALL_PADDING_MM = 250.0
WALL_RETURN_WIDTH_MM = 150.0
WALL_RETURN_HEIGHT_MM = 300.0
CANVAS_MARGIN_PX = 12.0
# Approximate glyph advance, TextPlus tracking unit and mask padding, all
# relative to the text height. Typography still needs host verification.
GLYPH_ADVANCE = 0.56
TRACKING_UNIT = 0.01
MASK_PADDING = 0.14


def _terminal_world(kind: str, anchor: Point, inward: Point, size: float) -> PreviewTerminal:
    """Terminal in world millimetres (y up), mirroring the committed geometry.

    Oracles: ameno_dimension_terminal_mesh.ms::createTerminal (closed arrow,
    diamond, dot) and ameno_dimension_graphics.ms::addTerminals (open arrow,
    tick). The committed dimension ignores terminal placement and angle:
    arrow bodies always sit inside the span and ticks lie on
    normalize(direction + perpendicular).
    """
    x, y = anchor
    ix, iy = inward
    px, py = -iy, ix  # perpendicular to the dimension line
    if kind == "none":
        return PreviewTerminal(kind, anchor)
    if kind == "dot":
        return PreviewTerminal(kind, anchor, radius=size * 0.35)
    if kind == "diamond":
        half = size * 0.5
        # createTerminal receives the outward direction: front, left, back, right.
        return PreviewTerminal(kind, anchor, points=(
            (x - ix * half, y - iy * half),
            (x + px * half, y + py * half),
            (x + ix * half, y + iy * half),
            (x - px * half, y - py * half),
        ))
    if kind in ("arrowClosed", "arrowOpen"):
        half_width = size * 0.25
        back = (x + ix * size, y + iy * size)
        wing_a = (back[0] + px * half_width, back[1] + py * half_width)
        wing_b = (back[0] - px * half_width, back[1] - py * half_width)
        if kind == "arrowOpen":
            return PreviewTerminal(kind, anchor, points=(anchor, wing_a, anchor, wing_b))
        return PreviewTerminal(kind, anchor, points=(anchor, wing_a, wing_b))
    # tick and unknown values. The layout direction runs from A to B, so it is
    # the inward vector at A and the opposite of it at B.
    dx, dy = (ix, iy) if ix > 0 or (ix == 0 and iy > 0) else (-ix, -iy)
    tx, ty = dx - dy, dy + dx
    length = (tx * tx + ty * ty) ** 0.5 or 1.0
    half = size * 0.5 / length
    return PreviewTerminal("tick", anchor, points=((x - tx * half, y - ty * half), (x + tx * half, y + ty * half)))


def _terminal_extent(terminal: PreviewTerminal) -> tuple[float, float, float, float]:
    xs = [point[0] for point in terminal.points] or [terminal.anchor[0]]
    ys = [point[1] for point in terminal.points] or [terminal.anchor[1]]
    r = terminal.radius
    return min(xs) - r, min(ys) - r, max(xs) + r, max(ys) + r


def _mm(value: Any) -> float:
    try:
        number = float(value)
    except (TypeError, ValueError):
        return 0.0
    return number if number == number and 0.0 < number < float("inf") else 0.0


def sample_span_mm(width: float, height: float) -> float:
    """3.50 m on landscape canvases (2:1 or wider), shorter down to 1.20 m."""
    aspect = max(1.0, width) / max(1.0, height)
    span = SAMPLE_SPAN_MM * min(1.0, aspect / 2.0)
    return max(MIN_SAMPLE_SPAN_MM, round(span / 50.0) * 50.0)


def build_preview_geometry(
    snapshot: StyleSnapshot,
    viewport_rect: Any,
    zoom: float = 1.0,
    text: str | None = None,
) -> PreviewGeometry:
    """Build all preview primitives without importing Qt or touching the scene.

    Every style dimension is a physical millimetre value converted with one
    scale, like ``toSceneUnits`` in the committed geometry. At 100% the whole
    sample (wall, dimension, terminals and label) fits the canvas; zoom and the
    style preview scale multiply that single scale, and magnification focuses
    on the left terminal and the label.
    """

    width, height = _rect_size(viewport_rect)
    external_zoom = max(0.25, min(4.0, float(zoom or 1.0)))
    style_scale = max(0.1, min(10.0, float(snapshot.preview_scale or 1.0)))
    effective_scale = external_zoom * style_scale

    span = sample_span_mm(width, height)
    if text is None:
        text = ("%.2f m" % (span / 1000.0)).replace(".", ",")
    gap = _mm(snapshot.extension_gap)
    overhang = _mm(snapshot.extension_overhang)
    terminal_size = _mm(snapshot.terminal_size)
    thickness = _mm(snapshot.line_thickness)
    font_size = _mm(snapshot.font_size)
    text_gap = _mm(snapshot.text_gap)
    try:
        tracking = float(snapshot.tracking or 0.0) * TRACKING_UNIT * font_size
    except (TypeError, ValueError):
        tracking = 0.0
    # The sample offset stays clear of the extension gap and the terminals.
    offset = max(SAMPLE_OFFSET_MM, gap + terminal_size * 0.5 + 100.0)

    # World frame in mm, y up: measured points on the wall face at y = 0.
    point_a, point_b = (0.0, offset), (span, offset)
    terminal_kind = str(snapshot.terminal_type or "tick")
    world_terminals = (
        _terminal_world(terminal_kind, point_a, (1.0, 0.0), terminal_size),
        _terminal_world(terminal_kind, point_b, (-1.0, 0.0), terminal_size),
    )
    text_width = max(font_size * 1.8, len(text) * font_size * GLYPH_ADVANCE + max(0, len(text) - 1) * tracking)
    text_base = offset + text_gap
    mask_padding = font_size * MASK_PADDING
    text_left = span * 0.5 - text_width * 0.5

    min_x = min(-WALL_PADDING_MM, text_left - mask_padding)
    max_x = max(span + WALL_PADDING_MM, text_left + text_width + mask_padding)
    min_y = -(WALL_THICKNESS_MM + WALL_RETURN_HEIGHT_MM)
    max_y = max(offset + overhang, text_base + font_size + mask_padding)
    for terminal in world_terminals:
        left, bottom, right, top = _terminal_extent(terminal)
        min_x, max_x = min(min_x, left), max(max_x, right)
        min_y, max_y = min(min_y, bottom), max(max_y, top)

    fit = min(
        max(1.0, width - CANVAS_MARGIN_PX * 2.0) / (max_x - min_x),
        max(1.0, height - CANVAS_MARGIN_PX * 2.0) / (max_y - min_y),
    )
    scale = fit * effective_scale
    # At fit the sample is centred. Magnifying past fit moves the focus to the
    # detail worth inspecting: the left terminal and the label, top-aligned.
    detail = max(0.0, min(1.0, effective_scale - 1.0))
    detail_y = max_y - (height * 0.5 - CANVAS_MARGIN_PX) / scale
    detail_x = (_terminal_extent(world_terminals[0])[0] + text_left + text_width + mask_padding) * 0.5
    centre_x = (min_x + max_x) * 0.5 * (1.0 - detail) + detail_x * detail
    centre_y = (min_y + max_y) * 0.5 * (1.0 - detail) + max(detail_y, (min_y + max_y) * 0.5) * detail

    def to_canvas(point: Point) -> Point:
        return (width * 0.5 + (point[0] - centre_x) * scale, height * 0.5 - (point[1] - centre_y) * scale)

    def rect(x: float, top: float, w: float, h: float) -> PreviewRect:
        left, canvas_top = to_canvas((x, top))
        return PreviewRect(left, canvas_top, w * scale, h * scale)

    wall_rects = (
        rect(-WALL_PADDING_MM, 0.0, span + WALL_PADDING_MM * 2.0, WALL_THICKNESS_MM),
        rect(-WALL_PADDING_MM, -WALL_THICKNESS_MM, WALL_RETURN_WIDTH_MM, WALL_RETURN_HEIGHT_MM),
        rect(span + WALL_PADDING_MM - WALL_RETURN_WIDTH_MM, -WALL_THICKNESS_MM,
             WALL_RETURN_WIDTH_MM, WALL_RETURN_HEIGHT_MM),
    )
    extension_segments = tuple(
        PreviewSegment(to_canvas((x, offset + overhang)), to_canvas((x, gap)))
        for x in (0.0, span)
    )
    dimension_segment = PreviewSegment(to_canvas(point_a), to_canvas(point_b))
    terminals = tuple(
        PreviewTerminal(
            terminal.kind,
            to_canvas(terminal.anchor),
            tuple(to_canvas(point) for point in terminal.points),
            terminal.radius * scale,
        )
        for terminal in world_terminals
    )

    font_size_px = font_size * scale
    text_baseline = to_canvas((text_left, text_base))
    padding_px = mask_padding * scale
    mask_rect = (
        text_baseline[0] - padding_px,
        text_baseline[1] - font_size_px - padding_px,
        text_width * scale + 2 * padding_px,
        font_size_px + 2 * padding_px,
    ) if snapshot.text_mask_enabled else None
    preview_text = PreviewText(
        value=text,
        baseline=text_baseline,
        font_name=str(snapshot.font_name or "Arial"),
        font_size_px=font_size_px,
        tracking_px=tracking * scale,
        bold=bool(snapshot.bold),
        italic=bool(snapshot.italic),
        color=_color_text(snapshot.text_color or snapshot.annotation_color),
        mask_rect=mask_rect,
    )
    return PreviewGeometry(
        width=width,
        height=height,
        line_color=_color_text(snapshot.annotation_color),
        line_thickness_px=thickness * scale,
        wall_rects=wall_rects,
        wall_reference_points=(to_canvas((0.0, 0.0)), to_canvas((span, 0.0))),
        extension_segments=extension_segments,
        dimension_segment=dimension_segment,
        terminals=terminals,
        text=preview_text,
        effective_scale=effective_scale,
    )
