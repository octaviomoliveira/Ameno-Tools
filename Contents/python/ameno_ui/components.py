"""Small stable presentation components with no scene or bridge dependency."""

from __future__ import annotations

from typing import Iterable, Optional, Sequence, Tuple

from .assets import pixmap
from .qt_compat import QtCore, QtWidgets


class BrandImage(QtWidgets.QLabel):
    def __init__(self, relative: str, width: int, height: int, fallback: str = "AMENO") -> None:
        super().__init__()
        self.setAlignment(QtCore.Qt.AlignmentFlag.AlignLeft | QtCore.Qt.AlignmentFlag.AlignVCenter)
        image = pixmap(relative, width, height)
        if image is None:
            self.setText(fallback)
            self.setObjectName("BrandFallback")
        else:
            self.setPixmap(image)
        self.setFixedHeight(height)


class PageHeader(QtWidgets.QWidget):
    def __init__(self, title: str, subtitle: str = "", eyebrow: str = "") -> None:
        super().__init__()
        layout = QtWidgets.QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 8)
        layout.setSpacing(4)
        if eyebrow:
            label = QtWidgets.QLabel(eyebrow.upper())
            label.setObjectName("Eyebrow")
            layout.addWidget(label)
        self.title = QtWidgets.QLabel(title)
        self.title.setObjectName("PageTitle")
        layout.addWidget(self.title)
        self.subtitle = QtWidgets.QLabel(subtitle)
        self.subtitle.setObjectName("PageSubtitle")
        self.subtitle.setWordWrap(True)
        self.subtitle.setVisible(bool(subtitle))
        layout.addWidget(self.subtitle)


class SectionHeading(QtWidgets.QWidget):
    def __init__(self, title: str, hint: str = "") -> None:
        super().__init__()
        layout = QtWidgets.QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(2)
        title_label = QtWidgets.QLabel(title)
        title_label.setObjectName("SectionTitle")
        layout.addWidget(title_label)
        if hint:
            hint_label = QtWidgets.QLabel(hint)
            hint_label.setObjectName("SectionHint")
            hint_label.setWordWrap(True)
            layout.addWidget(hint_label)


class ChoiceGroup(QtWidgets.QWidget):
    changed = QtCore.Signal(str)

    def __init__(self, choices: Sequence[Tuple[str, str, str]], columns: int = 2) -> None:
        super().__init__()
        self.buttons = QtWidgets.QButtonGroup(self)
        self.buttons.setExclusive(True)
        self._by_value = {}
        layout = QtWidgets.QGridLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(8)
        for index, (label, hint, value) in enumerate(choices):
            text = label if not hint else "%s\n%s" % (label, hint)
            widget = QtWidgets.QPushButton(text)
            widget.setCheckable(True)
            widget.setProperty("choice", True)
            widget.setProperty("choiceValue", value)
            widget.setAccessibleName(label)
            widget.setToolTip(hint)
            self.buttons.addButton(widget)
            self._by_value[value] = widget
            layout.addWidget(widget, index // columns, index % columns)
            widget.clicked.connect(lambda checked=False, item=value: self.changed.emit(item) if checked else None)
        if choices:
            self.set_value(choices[0][2], emit=False)

    def value(self) -> str:
        checked = self.buttons.checkedButton()
        return str(checked.property("choiceValue")) if checked is not None else ""

    def set_value(self, value: str, emit: bool = False) -> None:
        widget = self._by_value.get(value)
        if widget is None:
            return
        blocker = QtCore.QSignalBlocker(self.buttons)
        widget.setChecked(True)
        del blocker
        if emit:
            self.changed.emit(value)


class Disclosure(QtWidgets.QWidget):
    def __init__(self, label: str, content: QtWidgets.QWidget, expanded: bool = False) -> None:
        super().__init__()
        self.content = content
        self.toggle = QtWidgets.QPushButton()
        self.toggle.setProperty("quiet", True)
        self.toggle.setCheckable(True)
        self.toggle.setChecked(expanded)
        self.toggle.setAccessibleName(label)
        self._label = label
        layout = QtWidgets.QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(5)
        layout.addWidget(self.toggle)
        layout.addWidget(self.content)
        self.toggle.toggled.connect(self._set_expanded)
        self._set_expanded(expanded)

    def _set_expanded(self, expanded: bool) -> None:
        self.content.setVisible(expanded)
        self.toggle.setText(("−  " if expanded else "+  ") + self._label)


class StatusPill(QtWidgets.QLabel):
    def __init__(self, text: str = "") -> None:
        super().__init__(text)
        self.setObjectName("StatusPill")
        self.setAlignment(QtCore.Qt.AlignmentFlag.AlignCenter)


def set_layout_spacing(layout: QtWidgets.QLayout, spacing: int = 10) -> None:
    layout.setSpacing(spacing)


def add_widgets(layout: QtWidgets.QBoxLayout, widgets: Iterable[QtWidgets.QWidget]) -> None:
    for widget in widgets:
        layout.addWidget(widget)
