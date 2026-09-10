"""Shared page-shell sizing without rebuilding any page widget."""

from __future__ import annotations

from typing import Any

from .responsive import ResponsiveSpec


def apply_page_margins(page: Any, spec: ResponsiveSpec) -> None:
    """Adjust only the top-level layout margins of an existing page."""

    layout = page.layout()
    if layout is None:
        return
    top = max(18, spec.page_margin - 4)
    layout.setContentsMargins(spec.page_margin, top, spec.page_margin, spec.page_margin)
