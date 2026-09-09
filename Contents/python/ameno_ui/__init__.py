"""Ameno Python/Qt interface for 3ds Max 2026.

The package deliberately owns one application/window lifecycle. MAXScript only
launches this module and the scene is accessed through :mod:`bridge`.
"""

from __future__ import annotations

from typing import Optional

_application = None


def show(page: str = "login") -> bool:
    """Show the singleton window and request a page after authentication."""
    global _application
    from .application import AmenoApplication

    if _application is None:
        _application = AmenoApplication()
    _application.show(page or "login")
    return True


def close() -> bool:
    """Close the window idempotently without stopping 3ds Max."""
    global _application
    if _application is None:
        return True
    _application.close()
    return True


def is_open() -> bool:
    return bool(_application is not None and _application.is_open())


def _clear_application() -> None:
    global _application
    _application = None
