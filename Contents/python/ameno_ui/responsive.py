"""Pure responsive breakpoints for the Ameno Qt shell."""

from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True)
class ResponsiveSpec:
    mode: str
    sidebar_width: int
    page_margin: int


def spec_for_width(width: int | float) -> ResponsiveSpec:
    value = max(1, float(width))
    if value >= 1280:
        return ResponsiveSpec("wide", 208, 30)
    if value >= 900:
        return ResponsiveSpec("medium", 184, 24)
    return ResponsiveSpec("compact", 64, 16)
