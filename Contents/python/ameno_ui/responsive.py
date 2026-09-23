"""Pure viewport breakpoints for the Ameno Qt shell."""

from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class ResponsiveSpec:
    mode: str
    sidebar_width: int
    page_margin: int


RAIL_WIDTH = 64
MEDIUM_VIEWPORT_WIDTH = 760
WIDE_VIEWPORT_WIDTH = 1000
BREAKPOINT_HYSTERESIS = 16


def spec_for_viewport_width(
    width: int | float,
    previous_mode: str | None = None,
) -> ResponsiveSpec:
    """Resolve page density from usable viewport width.

    The rail is deliberately independent from page density, so changing a
    breakpoint cannot steal width from the viewport and reverse the decision.
    A small stateful dead band absorbs the width of a vertical scrollbar.
    """
    value = max(1, float(width))
    previous = previous_mode if previous_mode in ("compact", "medium", "wide") else None
    if previous == "compact":
        mode = "medium" if value >= MEDIUM_VIEWPORT_WIDTH + BREAKPOINT_HYSTERESIS else "compact"
    elif previous == "medium":
        if value < MEDIUM_VIEWPORT_WIDTH - BREAKPOINT_HYSTERESIS:
            mode = "compact"
        elif value >= WIDE_VIEWPORT_WIDTH + BREAKPOINT_HYSTERESIS:
            mode = "wide"
        else:
            mode = "medium"
    elif previous == "wide":
        mode = "medium" if value < WIDE_VIEWPORT_WIDTH - BREAKPOINT_HYSTERESIS else "wide"
    elif value >= WIDE_VIEWPORT_WIDTH:
        mode = "wide"
    elif value >= MEDIUM_VIEWPORT_WIDTH:
        mode = "medium"
    else:
        mode = "compact"

    margin = {"compact": 16, "medium": 24, "wide": 30}[mode]
    return ResponsiveSpec(mode, RAIL_WIDTH, margin)


def spec_for_width(width: int | float) -> ResponsiveSpec:
    """Compatibility alias; ``width`` now means usable page viewport width."""
    return spec_for_viewport_width(width)
