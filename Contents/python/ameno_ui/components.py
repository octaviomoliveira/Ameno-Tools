"""Small stable presentation components with no scene or bridge dependency."""

from __future__ import annotations

from typing import Iterable, Optional, Sequence, Tuple

from .assets import nav_icon, pixmap
from .qt_compat import QtCore, QtGui, QtWidgets


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


class ChoiceGlyph(QtWidgets.QWidget):
    """Small vector illustration used by a choice card."""

    def __init__(self, kind: str, parent=None) -> None:
        super().__init__(parent)
        self.kind = kind
        self.setFixedSize(56, 48)
        self.setAttribute(QtCore.Qt.WidgetAttribute.WA_TransparentForMouseEvents, True)

    def paintEvent(self, event) -> None:  # noqa: N802 - Qt API
        del event
        painter = QtGui.QPainter(self)
        painter.setRenderHint(QtGui.QPainter.RenderHint.Antialiasing, True)
        active = bool(getattr(self.parentWidget(), "isChecked", lambda: False)())
        pen = QtGui.QPen(QtGui.QColor("#FFFFFF" if active else "#B8B8B3"), 2.0)
        pen.setCapStyle(QtCore.Qt.PenCapStyle.RoundCap)
        pen.setJoinStyle(QtCore.Qt.PenJoinStyle.RoundJoin)
        painter.setPen(pen)
        painter.setBrush(QtCore.Qt.BrushStyle.NoBrush)

        if self.kind == "continuous":
            painter.drawLine(6, 24, 50, 24)
            for x in (8, 23, 36, 49):
                painter.drawLine(x, 14, x, 34)
        elif self.kind == "worldXY":
            path = QtGui.QPainterPath()
            path.moveTo(9, 8)
            path.lineTo(44, 8)
            path.lineTo(44, 29)
            path.lineTo(35, 29)
            path.lineTo(35, 40)
            path.lineTo(9, 40)
            path.closeSubpath()
            painter.drawPath(path)
            painter.drawLine(15, 8, 15, 19)
            painter.drawLine(9, 34, 18, 34)
        elif self.kind == "viewPlane":
            painter.drawLine(5, 39, 51, 39)
            painter.drawRect(12, 11, 21, 28)
            painter.drawRect(33, 22, 13, 17)
            painter.drawLine(19, 17, 19, 22)
            painter.drawLine(26, 17, 26, 22)
            painter.drawLine(19, 28, 19, 33)
            painter.drawLine(26, 28, 26, 33)
        else:
            painter.drawLine(7, 24, 49, 24)
            painter.drawLine(9, 14, 9, 34)
            painter.drawLine(47, 14, 47, 34)


class ChoiceIndicator(QtWidgets.QWidget):
    def __init__(self, owner: QtWidgets.QAbstractButton) -> None:
        super().__init__(owner)
        self.owner = owner
        self.setFixedSize(22, 22)
        self.setAttribute(QtCore.Qt.WidgetAttribute.WA_TransparentForMouseEvents, True)
        owner.toggled.connect(lambda _checked: self.update())

    def paintEvent(self, event) -> None:  # noqa: N802 - Qt API
        del event
        painter = QtGui.QPainter(self)
        painter.setRenderHint(QtGui.QPainter.RenderHint.Antialiasing, True)
        checked = self.owner.isChecked()
        painter.setPen(QtGui.QPen(QtGui.QColor("#F23B32" if checked else "#555753"), 1.6))
        painter.setBrush(QtCore.Qt.BrushStyle.NoBrush)
        painter.drawEllipse(2, 2, 18, 18)
        if checked:
            painter.setPen(QtCore.Qt.PenStyle.NoPen)
            painter.setBrush(QtGui.QColor("#F23B32"))
            painter.drawEllipse(6, 6, 10, 10)


class StatusDot(QtWidgets.QWidget):
    """Font-independent status mark for compact scene summaries."""

    def __init__(self, ready: bool = False, parent=None) -> None:
        super().__init__(parent)
        self._ready = ready
        self.setFixedSize(18, 18)
        self.setAccessibleName("Estado da cena")

    def set_ready(self, ready: bool) -> None:
        self._ready = bool(ready)
        self.update()

    def is_ready(self) -> bool:
        return self._ready

    def paintEvent(self, event) -> None:  # noqa: N802 - Qt API
        del event
        painter = QtGui.QPainter(self)
        painter.setRenderHint(QtGui.QPainter.RenderHint.Antialiasing, True)
        color = QtGui.QColor("#47C978" if self._ready else "#777873")
        painter.setPen(QtCore.Qt.PenStyle.NoPen)
        painter.setBrush(color)
        painter.drawEllipse(3, 3, 12, 12)


class CollapsibleSection(QtWidgets.QFrame):
    """Compact editor group with a native arrow and stable content widget."""

    def __init__(self, title: str, content: QtWidgets.QWidget, expanded: bool = False) -> None:
        super().__init__()
        self.setObjectName("EditorSection")
        self.content = content
        self.toggle = QtWidgets.QToolButton()
        self.toggle.setObjectName("SectionToggle")
        self.toggle.setText(title)
        self.toggle.setCheckable(True)
        self.toggle.setChecked(expanded)
        self.toggle.setToolButtonStyle(QtCore.Qt.ToolButtonStyle.ToolButtonTextBesideIcon)
        self.toggle.setAccessibleName(title)
        layout = QtWidgets.QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(0)
        layout.addWidget(self.toggle)
        layout.addWidget(content)
        self.toggle.toggled.connect(self._set_expanded)
        self._set_expanded(expanded)

    def _set_expanded(self, expanded: bool) -> None:
        self.content.setVisible(expanded)
        self.toggle.setArrowType(
            QtCore.Qt.ArrowType.DownArrow if expanded else QtCore.Qt.ArrowType.RightArrow
        )


class ColorControl(QtWidgets.QWidget):
    """Color swatch, readable value and explicit edit action."""

    edit_requested = QtCore.Signal()

    def __init__(self, label: str = "Editar cor") -> None:
        super().__init__()
        self.setObjectName("ColorControl")
        layout = QtWidgets.QHBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(8)
        self.swatch = QtWidgets.QFrame()
        self.swatch.setObjectName("ColorSwatch")
        self.swatch.setFixedSize(28, 28)
        layout.addWidget(self.swatch)
        self.value_label = QtWidgets.QLabel("#F5F5F5")
        self.value_label.setObjectName("ColorValue")
        self.value_label.setMinimumWidth(72)
        self.value_label.setTextInteractionFlags(QtCore.Qt.TextInteractionFlag.TextSelectableByMouse)
        layout.addWidget(self.value_label)
        layout.addStretch(1)
        self.edit_button = QtWidgets.QToolButton()
        self.edit_button.setText("Editar")
        self.edit_button.setAccessibleName(label)
        self.edit_button.clicked.connect(self.edit_requested)
        layout.addWidget(self.edit_button)
        self.set_color_text("245,245,245")

    def color_text(self) -> str:
        return str(self.property("colorText") or "245,245,245")

    def set_color_text(self, value: str) -> None:
        parts = []
        try:
            parts = [max(0, min(255, int(item.strip()))) for item in str(value).split(",")]
        except (TypeError, ValueError):
            parts = []
        if len(parts) != 3:
            parts = [245, 245, 245]
        normalized = "%d,%d,%d" % tuple(parts)
        self.setProperty("colorText", normalized)
        self.value_label.setText("#%02X%02X%02X" % tuple(parts))
        self.swatch.setStyleSheet("background-color: rgb(%s);" % normalized)


class ChoiceCard(QtWidgets.QPushButton):
    """Checkable card whose title and description can wrap independently."""

    def __init__(self, label: str, hint: str, value: str) -> None:
        super().__init__("")
        self.setObjectName("ChoiceCard")
        self.setCheckable(True)
        self.setProperty("choice", True)
        self.setProperty("choiceValue", value)
        self.setAccessibleName(label)
        self.setAccessibleDescription(hint)
        self.setToolTip(hint)
        self.setMinimumHeight(92)
        self.setSizePolicy(QtWidgets.QSizePolicy.Policy.Expanding, QtWidgets.QSizePolicy.Policy.Preferred)

        layout = QtWidgets.QHBoxLayout(self)
        layout.setContentsMargins(18, 14, 14, 14)
        layout.setSpacing(14)
        self.glyph = ChoiceGlyph(value, self)
        layout.addWidget(self.glyph, 0, QtCore.Qt.AlignmentFlag.AlignVCenter)

        copy = QtWidgets.QVBoxLayout()
        copy.setSpacing(2)
        self.title_label = QtWidgets.QLabel(label)
        self.title_label.setObjectName("ChoiceTitle")
        self.title_label.setWordWrap(True)
        self.title_label.setAttribute(QtCore.Qt.WidgetAttribute.WA_TransparentForMouseEvents, True)
        self.hint_label = QtWidgets.QLabel(hint)
        self.hint_label.setObjectName("ChoiceHint")
        self.hint_label.setWordWrap(True)
        self.hint_label.setAttribute(QtCore.Qt.WidgetAttribute.WA_TransparentForMouseEvents, True)
        copy.addWidget(self.title_label)
        copy.addWidget(self.hint_label)
        layout.addLayout(copy, 1)

        self.indicator = ChoiceIndicator(self)
        layout.addWidget(self.indicator, 0, QtCore.Qt.AlignmentFlag.AlignTop)
        self.toggled.connect(lambda _checked: self.glyph.update())


class ChoiceGroup(QtWidgets.QWidget):
    changed = QtCore.Signal(str)

    def __init__(self, choices: Sequence[Tuple[str, str, str]], columns: int = 2) -> None:
        super().__init__()
        self.buttons = QtWidgets.QButtonGroup(self)
        self.buttons.setExclusive(True)
        self._by_value = {}
        self._columns = max(1, columns)
        self._current_columns = self._columns
        self._layout = QtWidgets.QGridLayout(self)
        self._layout.setContentsMargins(0, 0, 0, 0)
        self._layout.setHorizontalSpacing(12)
        self._layout.setVerticalSpacing(10)
        for index, (label, hint, value) in enumerate(choices):
            widget = ChoiceCard(label, hint, value)
            self.buttons.addButton(widget)
            self._by_value[value] = widget
            self._layout.addWidget(widget, index // self._columns, index % self._columns)
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

    def items(self):
        return tuple(self._by_value.items())

    def resizeEvent(self, event) -> None:  # noqa: N802 - Qt API
        super().resizeEvent(event)
        columns = 1 if self.width() < 560 else self._columns
        if columns == self._current_columns:
            return
        self._current_columns = columns
        for index, widget in enumerate(self.buttons.buttons()):
            self._layout.addWidget(widget, index // columns, index % columns)


class SegmentedChoice(QtWidgets.QWidget):
    """Compact exclusive selector with a small QComboBox-compatible surface."""

    changed = QtCore.Signal(str)
    currentIndexChanged = QtCore.Signal(int)

    def __init__(self, choices: Sequence[Tuple[str, ...]]) -> None:
        super().__init__()
        self.setObjectName("SegmentedChoice")
        self.buttons = QtWidgets.QButtonGroup(self)
        self.buttons.setExclusive(True)
        self._items = list(choices)
        self._by_value = {}
        layout = QtWidgets.QHBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(0)
        last = len(self._items) - 1
        for index, item in enumerate(self._items):
            label, value = item[0], item[1]
            icon_name = item[2] if len(item) > 2 else ""
            widget = QtWidgets.QPushButton(label)
            widget.setCheckable(True)
            widget.setProperty("segment", True)
            widget.setProperty("segmentPosition", "first" if index == 0 else "last" if index == last else "middle")
            widget.setProperty("choiceValue", value)
            widget.setAccessibleName("Direção: " + label)
            widget.setMinimumHeight(36)
            if icon_name:
                widget.setIcon(nav_icon(icon_name))
                widget.setIconSize(QtCore.QSize(20, 20))
            self.buttons.addButton(widget, index)
            self._by_value[value] = widget
            layout.addWidget(widget, 1)
            widget.clicked.connect(lambda checked=False, item=value: self._emit_clicked(item) if checked else None)
        if self._items:
            self.set_value(self._items[0][1], emit=False)

    def value(self) -> str:
        checked = self.buttons.checkedButton()
        return str(checked.property("choiceValue")) if checked is not None else ""

    def currentData(self) -> str:
        return self.value()

    def currentIndex(self) -> int:
        return self.findData(self.value())

    def findData(self, value: str) -> int:
        for index, item in enumerate(self._items):
            item_value = item[1]
            if item_value == value:
                return index
        return -1

    def setCurrentIndex(self, index: int) -> None:
        if 0 <= index < len(self._items):
            self.set_value(self._items[index][1], emit=True)

    def set_value(self, value: str, emit: bool = False) -> None:
        widget = self._by_value.get(value)
        if widget is None or not widget.isEnabled():
            return
        changed = self.value() != value
        widget.setChecked(True)
        if emit and changed:
            index = self.findData(value)
            self.changed.emit(value)
            self.currentIndexChanged.emit(index)

    def _emit_clicked(self, value: str) -> None:
        index = self.findData(value)
        self.changed.emit(value)
        self.currentIndexChanged.emit(index)

    def set_item_enabled(self, value: str, enabled: bool) -> None:
        widget = self._by_value.get(value)
        if widget is not None:
            widget.setEnabled(enabled)

    def is_item_enabled(self, value: str) -> bool:
        widget = self._by_value.get(value)
        return bool(widget is not None and widget.isEnabled())


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
