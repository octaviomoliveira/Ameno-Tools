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
    "pressed": "#242424",
    "selected": "#2A1715",
    "selected_card": "#1D1312",
    "selected_strong": "#5A201C",
    "text": "#E8E8E0",
    "white": "#FFFFFF",
    "muted": "#8B8B85",
    "disabled": "#666666",
    "border": "#2A2A2A",
    # Interactive outlines stay above 3:1 against every normal dark surface.
    "control_border": "#6F716C",
    "control_border_hover": "#8B8D86",
    "focus": "#FF6B61",
    "red": "#E63B2E",
    "red_hover": "#F04A3D",
    # Dark enough to read as pressed, but still AA with dark text.
    "red_pressed": "#DF392D",
    "text_on_accent": "#090909",
    "success": "#75B798",
    "warning": "#E5B567",
    "error_text": "#FFB4AE",
    "icon": "#B8B8B3",
    "status_idle": "#777873",
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
QWidget#CreatePage QLabel#PageTitle { font-size: 25pt; font-weight: 500; }
QWidget#CreatePage QLabel#SectionTitle { font-size: 13pt; }
QWidget#StylesPage QLabel#PageTitle { font-size: 25pt; font-weight: 500; }
QLabel#EditorSectionTitle { color: %(white)s; font-size: 12pt; font-weight: 600; }
QLabel#FooterStatus { color: %(muted)s; font-size: 9.5pt; }
QLabel#FooterStatus[error="true"] { color: %(error_text)s; }
QLabel#ColorValue { color: %(text)s; font-family: "%(mono_font)s", "Consolas"; font-size: 9pt; }
QLabel#ChoiceTitle { color: %(white)s; font-size: 11.5pt; font-weight: 600; }
QLabel#ChoiceHint { color: %(muted)s; font-size: 9.5pt; }
QLabel#SelectionSummary { color: %(muted)s; font-size: 9.5pt; }
QLabel#SceneTitle { color: %(white)s; font-size: 11pt; font-weight: 600; }
QLabel#DirectionRule { color: %(muted)s; font-size: 9pt; padding: 0 3px; }
QLabel#Status {
    background-color: %(secondary)s;
    border: 1px solid %(border)s;
    border-radius: 7px;
    color: %(muted)s;
    padding: 9px 11px;
}
QLabel#Status[error="true"] { border-color: %(red)s; color: %(error_text)s; }
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
QFrame#SceneCard {
    background-color: %(elevated)s;
    border: 1px solid %(border)s;
    border-radius: 10px;
}
QFrame#SceneRule { color: %(border)s; }
QFrame#EditorSection, QFrame#PreviewPanel {
    background-color: %(secondary)s;
    border: 1px solid %(border)s;
    border-radius: 9px;
}
QFrame#StyleFooter {
    background-color: %(background)s;
    border-top: 1px solid %(border)s;
}
QFrame#ColorSwatch {
    border: 1px solid %(control_border)s;
    border-radius: 5px;
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
    border: 1px solid %(control_border)s;
    border-radius: 6px;
    color: %(text)s;
    min-height: 30px;
    padding: 2px 9px;
    selection-background-color: %(red)s;
    selection-color: %(white)s;
}
QLineEdit:focus, QComboBox:focus, QSpinBox:focus, QDoubleSpinBox:focus, QFontComboBox:focus {
    border: 2px solid %(focus)s;
}
QComboBox::drop-down { border: none; width: 24px; }
QComboBox QAbstractItemView {
    background-color: %(secondary)s;
    border: 1px solid %(control_border)s;
    selection-background-color: %(red)s;
    selection-color: %(text_on_accent)s;
}
QPushButton {
    background-color: %(secondary)s;
    border: 1px solid %(control_border)s;
    border-radius: 7px;
    color: %(text)s;
    min-height: 32px;
    padding: 2px 13px;
}
QPushButton:hover { background-color: %(hover)s; border-color: %(control_border_hover)s; }
QPushButton:focus { border: 2px solid %(focus)s; }
QPushButton:pressed { background-color: %(pressed)s; }
QPushButton:disabled { color: %(disabled)s; background-color: %(secondary)s; }
QPushButton[primary="true"] {
    background-color: %(red)s;
    border-color: %(red)s;
    color: %(text_on_accent)s;
    font-weight: 700;
    min-height: 40px;
}
QWidget#CreatePage QPushButton[primary="true"] { min-height: 44px; }
QPushButton[primary="true"]:hover { background-color: %(red_hover)s; }
QPushButton[primary="true"]:pressed { background-color: %(red_pressed)s; }
QPushButton[primary="true"]:focus { border: 2px solid %(white)s; }
QPushButton[quiet="true"] { background: transparent; border-color: transparent; color: %(muted)s; }
QPushButton[quiet="true"]:hover { color: %(white)s; background-color: %(hover)s; }
QPushButton[quiet="true"]:focus {
    background-color: %(hover)s;
    border: 2px solid %(focus)s;
    color: %(white)s;
}
QPushButton[nav="true"] {
    background: transparent;
    border-color: transparent;
    border-radius: 6px;
    color: %(muted)s;
    min-height: 44px;
    padding: 0;
    text-align: left;
}
QPushButton[nav="true"]:hover { color: %(white)s; background-color: %(hover)s; }
QPushButton[nav="true"]:checked {
    background-color: %(hover)s;
    border-left: 3px solid %(red)s;
    color: %(white)s;
    font-weight: 600;
}
QPushButton[nav="true"]:focus {
    background-color: %(hover)s;
    border: 2px solid %(focus)s;
    color: %(white)s;
}
QPushButton[nav="true"]:checked:focus {
    border: 2px solid %(focus)s;
    border-left: 3px solid %(red)s;
}
QPushButton[nav="true"][compact="true"] {
    padding: 4px 0;
    text-align: center;
}
QPushButton#ChoiceCard {
    background-color: %(secondary)s;
    border: 1px solid %(control_border)s;
    border-radius: 10px;
    padding: 0;
}
QPushButton#ChoiceCard:hover { background-color: %(hover)s; border-color: %(control_border_hover)s; }
QPushButton#ChoiceCard:checked { border: 2px solid %(red)s; background-color: %(selected_card)s; }
QPushButton#ChoiceCard:focus { border: 2px solid %(focus)s; }
QPushButton#ChoiceCard:checked:focus { border: 2px solid %(white)s; }
QPushButton[segment="true"] {
    background-color: %(secondary)s;
    border: 1px solid %(control_border)s;
    border-radius: 0;
    color: %(text)s;
    min-height: 36px;
    padding: 1px 10px;
}
QPushButton[segment="true"][segmentPosition="first"] {
    border-top-left-radius: 7px;
    border-bottom-left-radius: 7px;
}
QPushButton[segment="true"][segmentPosition="middle"],
QPushButton[segment="true"][segmentPosition="last"] { border-left: 0; }
QPushButton[segment="true"][segmentPosition="last"] {
    border-top-right-radius: 7px;
    border-bottom-right-radius: 7px;
}
QPushButton[segment="true"]:hover { background-color: %(hover)s; }
QPushButton[segment="true"]:checked {
    background-color: %(selected_strong)s;
    border: 1px solid %(red)s;
    color: %(white)s;
    font-weight: 600;
}
QPushButton[segment="true"]:disabled {
    background-color: #151515;
    border-color: %(border)s;
    color: #5E5E5A;
}
QPushButton[segment="true"]:focus { border: 2px solid %(focus)s; }
QPushButton[segment="true"]:checked:focus { border: 2px solid %(white)s; }
QToolButton {
    background-color: %(secondary)s;
    border: 1px solid %(control_border)s;
    border-radius: 7px;
    color: %(text)s;
    min-height: 32px;
    padding: 2px 13px;
}
QToolButton:hover { background-color: %(hover)s; border-color: %(control_border_hover)s; }
QToolButton:focus { border: 2px solid %(focus)s; }
QToolButton:disabled { color: %(disabled)s; }
QToolButton#SectionToggle {
    background-color: transparent;
    border: none;
    border-radius: 8px;
    color: %(white)s;
    font-size: 11pt;
    font-weight: 600;
    min-height: 36px;
    padding: 2px 12px;
    text-align: left;
}
QToolButton#SectionToggle:hover { background-color: %(hover)s; }
QToolButton#SectionToggle:checked { background-color: %(selected)s; }
QToolButton#SectionToggle:focus {
    background-color: %(hover)s;
    border: 2px solid %(focus)s;
}
QToolButton[primary="true"] {
    background-color: %(red)s;
    border-color: %(red)s;
    color: %(text_on_accent)s;
    font-weight: 700;
    min-height: 40px;
}
QToolButton[primary="true"]:hover { background-color: %(red_hover)s; }
QToolButton[primary="true"]:pressed { background-color: %(red_pressed)s; }
QToolButton[primary="true"]:focus { border: 2px solid %(white)s; }
QCheckBox, QRadioButton { min-height: 32px; spacing: 8px; }
QCheckBox::indicator, QRadioButton::indicator { width: 18px; height: 18px; }
QCheckBox::indicator:unchecked, QRadioButton::indicator:unchecked {
    background: %(secondary)s;
    border: 1px solid %(control_border)s;
    border-radius: 3px;
}
QRadioButton::indicator:unchecked { border-radius: 9px; }
QCheckBox::indicator:checked, QRadioButton::indicator:checked {
    background: %(red)s;
    border: 1px solid %(red)s;
    border-radius: 3px;
}
QRadioButton::indicator:checked { border-radius: 9px; }
QCheckBox::indicator:focus, QRadioButton::indicator:focus {
    border: 2px solid %(focus)s;
}
QCheckBox::indicator:checked:focus, QRadioButton::indicator:checked:focus {
    border: 2px solid %(white)s;
}
QSlider::groove:horizontal {
    height: 4px;
    background: %(control_border)s;
    border-radius: 2px;
}
QSlider::sub-page:horizontal { background: %(red)s; border-radius: 2px; }
QSlider::add-page:horizontal { background: %(control_border)s; border-radius: 2px; }
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
    border: 1px solid %(control_border)s;
    border-radius: 8px;
    outline: none;
    padding: 4px;
}
QListWidget::item { border-radius: 5px; padding: 8px; }
QListWidget::item:selected { background-color: %(selected)s; color: %(white)s; }
QMenu {
    background-color: %(secondary)s;
    border: 1px solid %(control_border)s;
    color: %(text)s;
    padding: 5px;
}
QMenu::item { border-radius: 4px; padding: 7px 24px 7px 10px; }
QMenu::item:selected { background-color: %(hover)s; color: %(white)s; }
QMenu::separator { background: %(border)s; height: 1px; margin: 5px; }
QScrollBar:vertical { background: %(background)s; width: 10px; margin: 0; }
QScrollBar::handle:vertical { background: %(control_border)s; border-radius: 5px; min-height: 32px; }
QScrollBar::add-line:vertical, QScrollBar::sub-line:vertical { height: 0; }
QSplitter::handle { background-color: %(control_border)s; width: 1px; }
QToolTip { background: %(secondary)s; color: %(text)s; border: 1px solid %(control_border)s; padding: 5px; }
""" % dict(c, ui_font=ui_font, mono_font=mono_font)


def apply_to(window: QtWidgets.QWidget) -> None:
    """Apply the theme only to the Ameno top-level window tree."""
    window.setStyleSheet(stylesheet())
    window.setFont(QtGui.QFont(register_fonts()[0], 10))
