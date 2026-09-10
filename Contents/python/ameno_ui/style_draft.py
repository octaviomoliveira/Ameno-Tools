"""Local, scene-independent editing model for the Qt style editor."""

from __future__ import annotations

from dataclasses import fields, replace
from typing import Any, Dict, Mapping

from .models import StyleSnapshot
from .qt_compat import QtCore


class StyleDraft(QtCore.QObject):
    """Mutable draft around an immutable StyleSnapshot.

    The draft is deliberately unaware of the bridge and of 3ds Max. It is
    always usable, including when the style library has not been loaded yet.
    """

    changed = QtCore.Signal(str, object)
    dirty_changed = QtCore.Signal(bool)

    _FIELD_NAMES = tuple(item.name for item in fields(StyleSnapshot))
    _ENUMS = {
        "terminal_type": {"tick", "arrowClosed", "arrowOpen", "dot", "none"},
        "terminal_placement": {"auto", "inside", "outside"},
    }
    _LIMITS = {
        "font_size": (1.0, 5000.0),
        "tracking": (-100.0, 100.0),
        "text_gap": (0.0, 1000.0),
        "line_thickness": (0.1, 100.0),
        "extension_overhang": (0.0, 2000.0),
        "extension_gap": (0.0, 2000.0),
        "terminal_size": (0.0, 2000.0),
        "terminal_angle": (0.0, 180.0),
        "preview_scale": (0.1, 10.0),
        "in_use": (0, 2**31 - 1),
    }

    def __init__(self, snapshot: StyleSnapshot | None = None, parent=None) -> None:
        super().__init__(parent)
        self._snapshot = self._coerce_snapshot(snapshot or StyleSnapshot("default", "Arquitetônico"))
        self._clean_snapshot = self._snapshot
        self._dirty = False

    @staticmethod
    def _number(value: Any, default: float, lower: float, upper: float) -> float:
        try:
            parsed = float(str(value).strip().replace(",", "."))
        except (TypeError, ValueError):
            parsed = default
        return max(lower, min(upper, parsed))

    @classmethod
    def _coerce_field(cls, name: str, value: Any, fallback: Any) -> Any:
        if name in cls._LIMITS:
            lower, upper = cls._LIMITS[name]
            number = cls._number(value, float(fallback), float(lower), float(upper))
            if name == "in_use":
                return int(round(number))
            return number
        if name in ("bold", "italic", "text_mask_enabled"):
            if isinstance(value, str):
                return value.strip().lower() in ("1", "true", "yes", "on", "sim")
            return bool(value)
        if name in cls._ENUMS:
            candidate = str(value or "")
            return candidate if candidate in cls._ENUMS[name] else str(fallback)
        if name in ("style_id", "name", "font_name", "annotation_color", "text_color"):
            text = "" if value is None else str(value)
            return text if text or name not in ("name", "font_name") else str(fallback)
        return value

    @classmethod
    def _coerce_snapshot(cls, snapshot: StyleSnapshot) -> StyleSnapshot:
        defaults = StyleSnapshot("default", "Arquitetônico")
        values: Dict[str, Any] = {}
        for name in cls._FIELD_NAMES:
            values[name] = cls._coerce_field(
                name,
                getattr(snapshot, name, getattr(defaults, name)),
                getattr(defaults, name),
            )
        return StyleSnapshot(**values)

    @property
    def dirty(self) -> bool:
        return self._dirty

    @property
    def snapshot(self) -> StyleSnapshot:
        return self._snapshot

    def value(self, field_name: str) -> Any:
        if field_name not in self._FIELD_NAMES:
            raise KeyError(field_name)
        return getattr(self._snapshot, field_name)

    def set_value(self, field_name: str, value: Any) -> bool:
        if field_name not in self._FIELD_NAMES:
            raise KeyError(field_name)
        current = getattr(self._snapshot, field_name)
        normalized = self._coerce_field(field_name, value, current)
        if normalized == current:
            return False
        self._snapshot = replace(self._snapshot, **{field_name: normalized})
        if not self._dirty:
            self._dirty = True
            self.dirty_changed.emit(True)
        self.changed.emit(field_name, normalized)
        return True

    def set(self, field_name: str, value: Any) -> bool:
        """Short alias useful for form adapters and tests."""
        return self.set_value(field_name, value)

    def update(self, values: Mapping[str, Any] | None = None, **changes: Any) -> None:
        merged = dict(values or {})
        merged.update(changes)
        for field_name, value in merged.items():
            self.set_value(field_name, value)

    def load(self, snapshot: StyleSnapshot) -> None:
        next_snapshot = self._coerce_snapshot(snapshot)
        self._snapshot = next_snapshot
        self._clean_snapshot = next_snapshot
        was_dirty = self._dirty
        self._dirty = False
        if was_dirty:
            self.dirty_changed.emit(False)

    def reset_to_default(self) -> None:
        self.load(StyleSnapshot("default", "Arquitetônico"))

    def mark_clean(self) -> None:
        self._clean_snapshot = self._snapshot
        if self._dirty:
            self._dirty = False
            self.dirty_changed.emit(False)

    def restore_clean(self) -> None:
        self.load(self._clean_snapshot)

    def to_snapshot(self) -> StyleSnapshot:
        return self._snapshot
