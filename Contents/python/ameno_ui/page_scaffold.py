"""Shared page-shell sizing without rebuilding any page widget."""

from __future__ import annotations

from typing import Any

from .responsive import ResponsiveSpec


def apply_page_margins(page: Any, spec: ResponsiveSpec) -> None:
    """Adjust only the top-level layout margins of an existing page."""

    layout = page.layout()
    if layout is None:
        return
    # A QScrollArea otherwise honors the page's natural (often text-driven)
    # size hint and creates a horizontal bar before the child layouts get a
    # chance to wrap. Ignore only the horizontal hint so the existing page
    # widget always receives the viewport width; vertical size remains natural
    # and scrollable.
    page.setMinimumWidth(0)
    page.setSizePolicy(
        page.sizePolicy().Policy.Ignored,
        page.sizePolicy().Policy.Expanding,
    )
    top = max(18, spec.page_margin - 4)
    layout.setContentsMargins(spec.page_margin, top, spec.page_margin, spec.page_margin)
