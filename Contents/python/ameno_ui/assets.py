"""Package-local asset lookup and pixmap cache for the Qt presentation."""

from __future__ import annotations

from pathlib import Path
from typing import Dict, Optional, Tuple

from .qt_compat import QtCore, QtGui


ASSET_ROOT = Path(__file__).resolve().parent / "assets"
_PIXMAPS: Dict[Tuple[str, int, int], QtGui.QPixmap] = {}


def asset_path(relative: str) -> Path:
    return ASSET_ROOT / relative


def pixmap(relative: str, width: int = 0, height: int = 0) -> Optional[QtGui.QPixmap]:
    """Return a cached pixmap, or None when an optional asset is unavailable."""
    key = (relative, int(width), int(height))
    cached = _PIXMAPS.get(key)
    if cached is not None:
        return QtGui.QPixmap(cached)
    source = QtGui.QPixmap(str(asset_path(relative)))
    if source.isNull():
        return None
    if width > 0 or height > 0:
        target_width = width if width > 0 else source.width()
        target_height = height if height > 0 else source.height()
        source = source.scaled(
            target_width,
            target_height,
            QtCore.Qt.AspectRatioMode.KeepAspectRatio,
            QtCore.Qt.TransformationMode.SmoothTransformation,
        )
    _PIXMAPS[key] = QtGui.QPixmap(source)
    return source


def icon(relative: str) -> QtGui.QIcon:
    source = pixmap(relative)
    return QtGui.QIcon(source) if source is not None else QtGui.QIcon()
