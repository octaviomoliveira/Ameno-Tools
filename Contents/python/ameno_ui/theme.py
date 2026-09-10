"""Ameno visual tokens and window-scoped Qt theme."""

from __future__ import annotations

from typing import Dict, List

from .assets import asset_path
from .qt_compat import QtGui, QtWidgets


COLORS: Dict[str, str] = {
    "background": "#0A0A0A",
    "secondary": "#121212",
    "elevated": "#161616",
    "hover": "#1C1C1C",
    "text": "#E8E8E0",
    "white": "#FFFFFF",
    "muted": "#8B8B85",
    "disabled": "#666666",
    "border": "#2A2A2A",
    "red": "#E63B2E",
    "red_dark": "#B92D23",
    "success": "#75B798",
    "warning": "#E5B567",
}

_FONT_IDS: List[int] = []
_FONTS_REGISTERED = False
UI_FONT = "Segoe UI"
MONO_FONT = "Consolas"


def register_fonts() -> tuple[str, str]:
    """Register bundled fonts once and return safe UI/mono family names."""
    global _FONTS_REGISTERED, UI_FONT, MONO_FONT
    if _FONTS_REGISTERED:
        return UI_FONT, MONO_FONT
    specs = (
        ("fonts/SpaceGrotesk-VariableFont_wght.ttf", "ui"),
        ("fonts/IBMPlexMono-Regular.ttf", "mono"),
    )
    for relative, role in specs:
        font_id = QtGui.QFontDatabase.addApplicationFont(str(asset_path(relative)))
        if font_id < 0:
            continue
        _FONT_IDS.append(font_id)
        families = QtGui.QFontDatabase.applicationFontFamilies(font_id)
        if not families:
            continue
        if role == "ui":
            UI_FONT = families[0]
        else:
            MONO_FONT = families[0]
    _FONTS_REGISTERED = True
    return UI_FONT, MONO_FONT


def stylesheet() -> str:
    ui_font, mono_font = register_fonts()
    c = COLORS
    return """
QWidget {
    background-color: %(background)s;
    color: %(text)s;
    font-family: "%(ui_font)s", "Segoe UI";
    font-size: 10.5pt;
}
QLabel, QCheckBox, QRadioButton { background-color: transparent; }
QStackedWidget, QStackedWidget > QWidget, QWidget#TransparentHost { background-color: transparent; }
QWidget#LoginPage, QWidget#AppShell, QScrollArea, QScrollArea > QWidget > QWidget {
    background-color: %(background)s;
}
QFrame#Sidebar {
    background-color: %(secondary)s;
    border-right: 1px solid %(border)s;
}
QLabel#BrandFallback { color: %(text)s; font-size: 25pt; font-weight: 600; }
QLabel#Eyebrow, QLabel#Meta, QLabel#Muted {
    color: %(muted)s;
}
QLabel#Eyebrow, QLabel#Meta {
    font-family: "%(mono_font)s", "Consolas";
    font-size: 8.5pt;
    letter-spacing: 1px;
}
QLabel#PageTitle { color: %(white)s; font-size: 22pt; font-weight: 600; }
QLabel#PageSubtitle { color: %(muted)s; font-size: 10pt; }
QLabel#SectionTitle { color: %(white)s; font-size: 12pt; font-weight: 600; }
QLabel#SectionHint { color: %(muted)s; font-size: 9pt; }
QLabel#Status {
    background-color: %(secondary)s;
    border: 1px solid %(border)s;
    border-radius: 7px;
    color: %(muted)s;
    padding: 9px 11px;
}
QLabel#Status[error="true"] { border-color: %(red)s; color: #FFB4AE; }
QLabel#StatusPill {
    background-color: %(secondary)s;
    border: 1px solid %(border)s;
    border-radius: 9px;
    color: %(muted)s;
    padding: 3px 8px;
}
QGroupBox#Card, QFrame#Card {
    background-color: %(elevated)s;
    border: 1px solid %(border)s;
    border-radius: 10px;
    margin-top: 8px;
    padding: 15px;
}
QGroupBox#Card::title {
    subcontrol-origin: margin;
    left: 14px;
    padding: 0 5px;
    color: %(white)s;
    font-weight: 600;
}
QLineEdit, QComboBox, QSpinBox, QDoubleSpinBox, QFontComboBox {
    background-color: %(secondary)s;
    border: 1px solid %(border)s;
    border-radius: 6px;
    color: %(text)s;
    min-height: 30px;
    padding: 2px 9px;
    selection-background-color: %(red)s;
    selection-color: %(white)s;
}
QLineEdit:focus, QComboBox:focus, QSpinBox:focus, QDoubleSpinBox:focus, QFontComboBox:focus {
    border: 1px solid %(red)s;
}
QComboBox::drop-down { border: none; width: 24px; }
QComboBox QAbstractItemView {
    background-color: %(secondary)s;
    border: 1px solid %(border)s;
    selection-background-color: %(red)s;
    selection-color: %(white)s;
}
QPushButton {
    background-color: %(secondary)s;
    border: 1px solid %(border)s;
    border-radius: 7px;
    color: %(text)s;
    min-height: 32px;
    padding: 2px 13px;
}
QPushButton:hover { background-color: %(hover)s; border-color: #3A3A3A; }
QPushButton:focus { border: 1px solid %(red)s; }
QPushButton:pressed { background-color: #242424; }
QPushButton:disabled { color: %(disabled)s; background-color: %(secondary)s; }
QPushButton[primary="true"] {
    background-color: %(red)s;
    border-color: %(red)s;
    color: #090909;
    font-weight: 700;
    min-height: 40px;
}
QPushButton[primary="true"]:hover { background-color: #F04A3D; }
QPushButton[primary="true"]:pressed { background-color: %(red_dark)s; }
QPushButton[quiet="true"] { background: transparent; border-color: transparent; color: %(muted)s; }
QPushButton[quiet="true"]:hover { color: %(white)s; background-color: %(hover)s; }
QPushButton[nav="true"] {
    background: transparent;
    border-color: transparent;
    border-radius: 6px;
    color: %(muted)s;
    padding: 4px 12px;
    text-align: left;
}
QPushButton[nav="true"]:hover { color: %(white)s; background-color: %(hover)s; }
QPushButton[nav="true"]:checked {
    background-color: %(hover)s;
    border-left: 3px solid %(red)s;
    color: %(white)s;
    font-weight: 600;
}
QPushButton[nav="true"][compact="true"] {
    padding: 4px 0;
    text-align: center;
}
QPushButton[choice="true"] {
    background-color: %(secondary)s;
    border: 1px solid %(border)s;
    border-radius: 9px;
    min-height: 62px;
    padding: 8px 12px;
    text-align: left;
}
QPushButton[choice="true"]:checked { border: 2px solid %(red)s; background-color: #1D1312; }
QToolButton {
    background-color: %(secondary)s;
    border: 1px solid %(border)s;
    border-radius: 7px;
    color: %(text)s;
    min-height: 32px;
    padding: 2px 13px;
}
QToolButton:hover { background-color: %(hover)s; border-color: #3A3A3A; }
QToolButton:focus { border: 1px solid %(red)s; }
QToolButton:disabled { color: %(disabled)s; }
QCheckBox { spacing: 8px; }
QCheckBox::indicator { width: 16px; height: 16px; }
QCheckBox::indicator:unchecked { background: %(secondary)s; border: 1px solid #4A4A4A; border-radius: 3px; }
QCheckBox::indicator:checked { background: %(red)s; border: 1px solid %(red)s; border-radius: 3px; }
QSlider::groove:horizontal {
    height: 4px;
    background: #2A2A2A;
    border-radius: 2px;
}
QSlider::sub-page:horizontal { background: %(red)s; border-radius: 2px; }
QSlider::add-page:horizontal { background: #2A2A2A; border-radius: 2px; }
QSlider::handle:horizontal {
    width: 14px;
    margin: -5px 0;
    background: %(text)s;
    border: 1px solid %(red)s;
    border-radius: 7px;
}
QSlider:disabled { opacity: 0.55; }
QListWidget {
    background-color: %(secondary)s;
    border: 1px solid %(border)s;
    border-radius: 8px;
    outline: none;
    padding: 4px;
}
QListWidget::item { border-radius: 5px; padding: 8px; }
QListWidget::item:selected { background-color: #2A1715; color: %(white)s; }
QMenu {
    background-color: %(secondary)s;
    border: 1px solid %(border)s;
    color: %(text)s;
    padding: 5px;
}
QMenu::item { border-radius: 4px; padding: 7px 24px 7px 10px; }
QMenu::item:selected { background-color: %(hover)s; color: %(white)s; }
QMenu::separator { background: %(border)s; height: 1px; margin: 5px; }
QScrollBar:vertical { background: %(background)s; width: 10px; margin: 0; }
QScrollBar::handle:vertical { background: #343434; border-radius: 5px; min-height: 30px; }
QScrollBar::add-line:vertical, QScrollBar::sub-line:vertical { height: 0; }
QSplitter::handle { background-color: %(border)s; width: 1px; }
QToolTip { background: %(secondary)s; color: %(text)s; border: 1px solid %(border)s; padding: 5px; }
""" % dict(c, ui_font=ui_font, mono_font=mono_font)


def apply_to(window: QtWidgets.QWidget) -> None:
    """Apply the theme only to the Ameno top-level window tree."""
    window.setStyleSheet(stylesheet())
    window.setFont(QtGui.QFont(register_fonts()[0], 10))
