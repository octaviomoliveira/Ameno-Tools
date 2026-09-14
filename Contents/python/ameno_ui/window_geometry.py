"""Pure geometry policy for the native Ameno window.

Qt persists the native byte array; this module only decides whether the
resulting client rectangle is usable on the monitors available now. Keeping
the policy pure makes monitor removal and DPI changes testable without opening
or moving a real 3ds Max window.
"""

from __future__ import annotations

from collections.abc import Iterable

from .qt_compat import QtCore


DEFAULT_WINDOW_SIZE = QtCore.QSize(780, 1020)
DEFAULT_SCREEN_MARGIN = 12
MIN_VISIBLE_WIDTH = 120
MIN_VISIBLE_HEIGHT = 48


def _valid_rect(rect: QtCore.QRect) -> bool:
    return rect.isValid() and rect.width() > 0 and rect.height() > 0


def _inset(rect: QtCore.QRect, margin: int) -> QtCore.QRect:
    value = max(0, int(margin))
    if rect.width() > value * 2 and rect.height() > value * 2:
        return rect.adjusted(value, value, -value, -value)
    return QtCore.QRect(rect)


def initial_window_geometry(available: QtCore.QRect) -> QtCore.QRect:
    """Center the preferred portrait ratio and scale it down when necessary."""
    if not _valid_rect(available):
        return QtCore.QRect(QtCore.QPoint(0, 0), DEFAULT_WINDOW_SIZE)
    usable = _inset(available, DEFAULT_SCREEN_MARGIN)
    scale = min(
        1.0,
        usable.width() / DEFAULT_WINDOW_SIZE.width(),
        usable.height() / DEFAULT_WINDOW_SIZE.height(),
    )
    size = QtCore.QSize(
        max(1, min(usable.width(), round(DEFAULT_WINDOW_SIZE.width() * scale))),
        max(1, min(usable.height(), round(DEFAULT_WINDOW_SIZE.height() * scale))),
    )
    result = QtCore.QRect(QtCore.QPoint(0, 0), size)
    result.moveCenter(usable.center())
    return result


def visible_enough(rect: QtCore.QRect, available_rects: Iterable[QtCore.QRect]) -> bool:
    """Require an accessible title region, not merely one coincident pixel."""
    if not _valid_rect(rect):
        return False
    required_width = min(MIN_VISIBLE_WIDTH, rect.width())
    required_height = min(MIN_VISIBLE_HEIGHT, rect.height())
    for available in available_rects:
        intersection = rect.intersected(available)
        if intersection.width() >= required_width and intersection.height() >= required_height:
            return True
    return False


def _intersection_area(first: QtCore.QRect, second: QtCore.QRect) -> int:
    intersection = first.intersected(second)
    return max(0, intersection.width()) * max(0, intersection.height())


def _point_distance_squared(point: QtCore.QPoint, rect: QtCore.QRect) -> int:
    x = min(max(point.x(), rect.left()), rect.right())
    y = min(max(point.y(), rect.top()), rect.bottom())
    return (point.x() - x) ** 2 + (point.y() - y) ** 2


def recover_window_geometry(
    restored: QtCore.QRect,
    available_rects: Iterable[QtCore.QRect],
    preferred: QtCore.QRect | None = None,
) -> QtCore.QRect:
    """Fit a restored rect wholly inside its best current monitor.

    Position and size are preserved when already safe. A removed monitor uses
    the preferred/current monitor, then the nearest available monitor.
    """
    areas = [QtCore.QRect(rect) for rect in available_rects if _valid_rect(rect)]
    if not areas:
        return QtCore.QRect(restored)
    if not _valid_rect(restored):
        fallback = preferred if preferred is not None and _valid_rect(preferred) else areas[0]
        return initial_window_geometry(fallback)
    preferred_rect = QtCore.QRect(preferred) if preferred is not None and _valid_rect(preferred) else None
    overlap = [_intersection_area(restored, area) for area in areas]
    if max(overlap, default=0) > 0:
        target = areas[overlap.index(max(overlap))]
    elif preferred_rect is not None and preferred_rect in areas:
        target = areas[areas.index(preferred_rect)]
    else:
        center = restored.center()
        target = min(areas, key=lambda area: _point_distance_squared(center, area))

    if target.contains(restored):
        return QtCore.QRect(restored)
    usable = _inset(target, DEFAULT_SCREEN_MARGIN)
    width = min(max(1, restored.width()), usable.width())
    height = min(max(1, restored.height()), usable.height())
    left = min(max(restored.left(), usable.left()), usable.right() - width + 1)
    top = min(max(restored.top(), usable.top()), usable.bottom() - height + 1)
    return QtCore.QRect(left, top, width, height)


def remap_window_geometry(
    restored: QtCore.QRect,
    previous_available: QtCore.QRect,
    current_available: QtCore.QRect,
) -> QtCore.QRect:
    """Preserve relative placement when the same monitor changes work area."""
    if not (_valid_rect(restored) and _valid_rect(previous_available) and _valid_rect(current_available)):
        return QtCore.QRect(restored)

    def coordinate(value: int, old_start: int, old_span: int, new_start: int, new_span: int) -> int:
        if old_span <= 0:
            ratio = 0.5
        else:
            ratio = min(1.0, max(0.0, (value - old_start) / old_span))
        return new_start + round(ratio * max(0, new_span))

    left = coordinate(
        restored.left(),
        previous_available.left(),
        previous_available.width() - restored.width(),
        current_available.left(),
        current_available.width() - restored.width(),
    )
    top = coordinate(
        restored.top(),
        previous_available.top(),
        previous_available.height() - restored.height(),
        current_available.top(),
        current_available.height() - restored.height(),
    )
    return QtCore.QRect(QtCore.QPoint(left, top), restored.size())
