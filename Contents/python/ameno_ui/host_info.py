"""Host metadata with feature detection, not version-number branching."""

from __future__ import annotations

import platform


def collect() -> dict:
    data = {
        "python": platform.python_version(),
        "binding": "PySide6",
        "qt": "6.5.3",
        "max": "3ds Max 2026",
    }
    try:
        from PySide6 import QtCore

        data["qt"] = QtCore.qVersion()
    except Exception:
        pass
    try:
        from pymxs import runtime as rt

        version = rt.maxVersion()
        values = list(version) if isinstance(version, (list, tuple)) else []
        if values:
            data["max"] = "3ds Max %s" % values[0]
    except Exception:
        pass
    return data
