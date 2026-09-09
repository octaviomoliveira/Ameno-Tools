"""Presentation helpers kept independent from scene access."""

from __future__ import annotations

from .qt_compat import QtCore, QtGui, QtWidgets


def button(text: str, slot=None, primary: bool = False) -> QtWidgets.QPushButton:
    widget = QtWidgets.QPushButton(text)
    widget.setMinimumHeight(32)
    if primary:
        widget.setProperty("primary", True)
    if slot is not None:
        widget.clicked.connect(slot)
    return widget


def group(title: str) -> QtWidgets.QGroupBox:
    box = QtWidgets.QGroupBox(title)
    box.setObjectName("Card")
    return box


def scroll(widget: QtWidgets.QWidget) -> QtWidgets.QScrollArea:
    area = QtWidgets.QScrollArea()
    area.setWidgetResizable(True)
    area.setFrameShape(QtWidgets.QFrame.Shape.NoFrame)
    area.setWidget(widget)
    return area


def message_label() -> QtWidgets.QLabel:
    label = QtWidgets.QLabel()
    label.setWordWrap(True)
    label.setTextInteractionFlags(QtCore.Qt.TextInteractionFlag.TextSelectableByMouse)
    label.setObjectName("Status")
    return label


def set_message(label: QtWidgets.QLabel, text: str, error: bool = False) -> None:
    label.setText(text)
    label.setProperty("error", bool(error))
    label.style().unpolish(label)
    label.style().polish(label)
