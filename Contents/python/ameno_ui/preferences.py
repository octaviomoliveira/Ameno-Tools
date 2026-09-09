"""Non-sensitive local UI preferences with a deterministic test seam."""

from __future__ import annotations

import os

from .qt_compat import QtCore


def settings() -> QtCore.QSettings:
    override = os.environ.get("AMENO_SETTINGS_FILE", "").strip()
    if override:
        return QtCore.QSettings(override, QtCore.QSettings.Format.IniFormat)
    return QtCore.QSettings("Ameno", "AmenoTools")
