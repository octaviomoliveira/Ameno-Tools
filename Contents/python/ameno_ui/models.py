"""Immutable primitive snapshots exchanged with the MAXScript bridge."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any, List, Sequence


def _text(value: Any, default: str = "") -> str:
    return default if value is None else str(value)


def _items(value: Any) -> list:
    if value is None:
        return []
    if isinstance(value, (list, tuple)):
        return list(value)
    try:
        return list(value)
    except Exception:
        return []


@dataclass(frozen=True)
class SceneSnapshot:
    status: str = "notPrepared"
    status_label: str = "Não preparada"
    detail: str = ""
    dimension_count: int = 0
    renderer_label: str = "Renderer desconhecido"
    renderer_state: str = "sem adapter"
    renderer_family: str = "unknown"
    renderer_engine: str = "unknown"
    version: str = ""

    @classmethod
    def from_wire(cls, value: Any) -> "SceneSnapshot":
        data = _items(value)
        data += [None] * (9 - len(data))
        try:
            count = int(data[3] or 0)
        except Exception:
            count = 0
        return cls(
            _text(data[0], "notPrepared"),
            _text(data[1], "Não preparada"),
            _text(data[2]),
            count,
            _text(data[4], "Renderer desconhecido"),
            _text(data[5], "sem adapter"),
            _text(data[6], "unknown"),
            _text(data[7], "unknown"),
            _text(data[8]),
        )


@dataclass(frozen=True)
class CreateSnapshot:
    mode: str = "aligned"
    plane: str = "worldXY"
    style_id: str = "default"
    unit: str = "meters"
    precision: int = 2
    text_follows_line: bool = True

    @classmethod
    def from_wire(cls, value: Any) -> "CreateSnapshot":
        data = _items(value)
        data += [None] * (6 - len(data))
        try:
            precision = int(data[4] if data[4] is not None else 2)
        except Exception:
            precision = 2
        return cls(_text(data[0], "aligned"), _text(data[1], "worldXY"), _text(data[2], "default"), _text(data[3], "meters"), precision, bool(data[5]) if data[5] is not None else True)


@dataclass(frozen=True)
class StyleSnapshot:
    style_id: str
    name: str
    font_name: str = "Arial"
    font_size: float = 140.0
    bold: bool = False
    italic: bool = False
    tracking: float = 0.0
    text_gap: float = 60.0
    line_thickness: float = 1.5
    extension_overhang: float = 80.0
    extension_gap: float = 0.0
    terminal_type: str = "tick"
    terminal_size: float = 100.0
    text_mask_enabled: bool = True
    annotation_color: str = "245,245,245"
    text_color: str = ""
    terminal_placement: str = "auto"
    terminal_angle: float = 45.0
    preview_scale: float = 1.0
    in_use: int = 0

    @classmethod
    def from_wire(cls, value: Any) -> "StyleSnapshot":
        data = _items(value)
        data += [None] * (20 - len(data))
        floats = []
        for index, default in ((3, 140.0), (6, 0.0), (7, 60.0), (8, 1.5), (9, 80.0), (10, 0.0), (12, 100.0), (17, 45.0), (18, 1.0)):
            try:
                floats.append((index, float(data[index] if data[index] is not None else default)))
            except Exception:
                floats.append((index, default))
        values = {
            "style_id": _text(data[0], "default"),
            "name": _text(data[1], "Estilo"),
            "font_name": _text(data[2], "Arial"),
            "bold": bool(data[4]),
            "italic": bool(data[5]),
            "terminal_type": _text(data[11], "tick"),
            "text_mask_enabled": bool(data[13]) if data[13] is not None else True,
            "annotation_color": _text(data[14], "245,245,245"),
            "text_color": _text(data[15]),
            "terminal_placement": _text(data[16], "auto"),
            "in_use": int(data[19] or 0) if str(data[19] or "0").lstrip("-").isdigit() else 0,
        }
        for index, value_float in floats:
            values[{3: "font_size", 6: "tracking", 7: "text_gap", 8: "line_thickness", 9: "extension_overhang", 10: "extension_gap", 12: "terminal_size", 17: "terminal_angle", 18: "preview_scale"}[index]] = value_float
        return cls(**values)


@dataclass(frozen=True)
class AuditSnapshot:
    dimension_id: str
    mode: str
    measured_mm: float
    display_mm: float
    delta_mm: float
    measured_text: str
    display_text: str
    delta_text: str
    manual_reason: str
    is_manual: bool
    anchor_type: str
    anchor_desc: str
    is_orphan: bool
    orphan_reason: str

    @classmethod
    def from_wire(cls, value: Any) -> "AuditSnapshot | None":
        data = _items(value)
        if len(data) < 14:
            return None
        def number(index: int) -> float:
            try:
                return float(data[index] or 0.0)
            except Exception:
                return 0.0
        return cls(_text(data[0]), _text(data[1], "measured"), number(2), number(3), number(4), _text(data[5]), _text(data[6]), _text(data[7]), _text(data[8]), bool(data[9]), _text(data[10], "world"), _text(data[11], "Mundial"), bool(data[12]), _text(data[13]))
