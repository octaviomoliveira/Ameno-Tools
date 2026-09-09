"""Qt style editor rebuilt independently from the former WPF presentation."""

from __future__ import annotations

from dataclasses import replace
from typing import Dict, List, Optional

from .bridge import BridgeError, UiBridge
from .common import button, group, message_label, scroll, set_message
from .models import StyleSnapshot
from .qt_compat import QtCore, QtGui, QtWidgets


def color_text_to_qcolor(value: str) -> QtGui.QColor:
    try:
        parts = [int(item.strip()) for item in str(value or "").split(",")]
        if len(parts) == 3:
            return QtGui.QColor(max(0, min(255, parts[0])), max(0, min(255, parts[1])), max(0, min(255, parts[2])))
    except Exception:
        pass
    return QtGui.QColor(245, 245, 245)


def qcolor_to_text(value: QtGui.QColor) -> str:
    return "%d,%d,%d" % (value.red(), value.green(), value.blue())


class PreviewWidget(QtWidgets.QWidget):
    def __init__(self) -> None:
        super().__init__()
        self.setMinimumHeight(190)
        self._style: Optional[StyleSnapshot] = None
        self._dark = True
        self._zoom = 1.0

    def set_model(self, style: Optional[StyleSnapshot], dark: bool, zoom: float) -> None:
        self._style = style
        self._dark = dark
        self._zoom = zoom
        self.update()

    def paintEvent(self, event) -> None:  # noqa: N802 - Qt API
        painter = QtGui.QPainter(self)
        painter.setRenderHint(QtGui.QPainter.RenderHint.Antialiasing, True)
        bg = QtGui.QColor("#151922" if self._dark else "#f4f5f7")
        painter.fillRect(self.rect(), bg)
        style = self._style or StyleSnapshot("default", "Arquitetônico")
        fg = color_text_to_qcolor(style.annotation_color)
        if not fg.isValid():
            fg = QtGui.QColor("#f3f4f6" if self._dark else "#1f2937")
        pen = QtGui.QPen(fg)
        pen.setWidthF(max(0.5, style.line_thickness * self._zoom))
        painter.setPen(pen)
        left = 28.0
        right = float(self.width() - 28)
        center = float(self.height()) * 0.62
        painter.drawLine(QtCore.QPointF(left, center), QtCore.QPointF(right, center))
        painter.drawLine(QtCore.QPointF(left, center - 28), QtCore.QPointF(left, center + 28))
        painter.drawLine(QtCore.QPointF(right, center - 28), QtCore.QPointF(right, center + 28))
        terminal = style.terminal_type
        if terminal in ("tick", "arrowOpen", "arrowClosed"):
            painter.drawLine(QtCore.QPointF(left, center), QtCore.QPointF(left + 10, center - 10))
            painter.drawLine(QtCore.QPointF(right, center), QtCore.QPointF(right - 10, center + 10))
        elif terminal == "dot":
            painter.setBrush(fg)
            painter.drawEllipse(QtCore.QPointF(left - 4, center - 4), 4, 4)
            painter.drawEllipse(QtCore.QPointF(right - 4, center - 4), 4, 4)
        font = QtGui.QFont(style.font_name, max(8, int(style.font_size * 0.16 * self._zoom)))
        font.setBold(style.bold)
        font.setItalic(style.italic)
        painter.setFont(font)
        text = "3,50 m"
        text_rect = painter.fontMetrics().boundingRect(text)
        text_x = (self.width() - text_rect.width()) / 2.0
        text_y = center - max(10, style.text_gap * 0.15)
        if style.text_mask_enabled:
            mask = QtCore.QRectF(text_x - 8, text_y - text_rect.height(), text_rect.width() + 16, text_rect.height() + 8)
            painter.fillRect(mask, bg)
        painter.setPen(fg)
        painter.drawText(QtCore.QPointF(text_x, text_y), text)
        painter.end()


class StylesPage(QtWidgets.QWidget):
    def __init__(self, bridge: UiBridge) -> None:
        super().__init__()
        self.bridge = bridge
        self._styles: List[StyleSnapshot] = []
        self._current: Optional[StyleSnapshot] = None
        self._loading = False

        root = QtWidgets.QVBoxLayout(self)
        root.setContentsMargins(22, 18, 22, 22)
        title = QtWidgets.QLabel("Estilos")
        title.setObjectName("PageTitle")
        root.addWidget(title)
        root.addWidget(QtWidgets.QLabel("O preview é desenhado em 2D pela própria interface e nunca toca a viewport."), 0)

        split = QtWidgets.QSplitter(QtCore.Qt.Orientation.Horizontal)
        root.addWidget(split, 1)

        left = QtWidgets.QWidget()
        left_layout = QtWidgets.QVBoxLayout(left)
        self.list_widget = QtWidgets.QListWidget()
        self.list_widget.setMinimumWidth(190)
        self.list_widget.currentRowChanged.connect(self._select_row)
        left_layout.addWidget(self.list_widget, 1)
        left_buttons = QtWidgets.QGridLayout()
        left_buttons.addWidget(button("Novo", self.new_style), 0, 0)
        left_buttons.addWidget(button("Duplicar", self.duplicate_style), 0, 1)
        left_buttons.addWidget(button("Excluir", self.delete_style), 1, 0, 1, 2)
        left_layout.addLayout(left_buttons)
        split.addWidget(left)

        right = QtWidgets.QWidget()
        right_layout = QtWidgets.QVBoxLayout(right)
        form_box = group("Propriedades")
        form = QtWidgets.QFormLayout(form_box)
        self.name = QtWidgets.QLineEdit()
        self.font = QtWidgets.QFontComboBox()
        self.font_size = QtWidgets.QDoubleSpinBox()
        self.font_size.setRange(1, 5000)
        self.font_size.setDecimals(1)
        self.tracking = QtWidgets.QDoubleSpinBox()
        self.tracking.setRange(-100, 100)
        self.tracking.setDecimals(1)
        self.text_gap = QtWidgets.QDoubleSpinBox()
        self.text_gap.setRange(0, 1000)
        self.text_gap.setDecimals(1)
        self.line_thickness = QtWidgets.QDoubleSpinBox()
        self.line_thickness.setRange(0.1, 100)
        self.line_thickness.setDecimals(1)
        self.overhang = QtWidgets.QDoubleSpinBox()
        self.overhang.setRange(0, 2000)
        self.overhang.setDecimals(1)
        self.extension_gap = QtWidgets.QDoubleSpinBox()
        self.extension_gap.setRange(0, 2000)
        self.extension_gap.setDecimals(1)
        self.terminal_size = QtWidgets.QDoubleSpinBox()
        self.terminal_size.setRange(0, 2000)
        self.terminal_size.setDecimals(1)
        self.terminal_angle = QtWidgets.QDoubleSpinBox()
        self.terminal_angle.setRange(0, 180)
        self.terminal_angle.setDecimals(1)
        self.terminal = QtWidgets.QComboBox()
        for label, value in (("Tick", "tick"), ("Seta fechada", "arrowClosed"), ("Seta aberta", "arrowOpen"), ("Ponto", "dot"), ("Nenhum", "none")):
            self.terminal.addItem(label, value)
        self.placement = QtWidgets.QComboBox()
        for label, value in (("Automático", "auto"), ("Interno", "inside"), ("Externo", "outside")):
            self.placement.addItem(label, value)
        self.bold = QtWidgets.QCheckBox("Negrito")
        self.italic = QtWidgets.QCheckBox("Itálico")
        self.mask = QtWidgets.QCheckBox("Máscara de texto")
        self.annotation_color = button("Cor da cota", self.choose_color)
        form.addRow("Nome", self.name)
        form.addRow("Fonte", self.font)
        form.addRow("Tamanho", self.font_size)
        form.addRow("Tracking", self.tracking)
        form.addRow("Afastamento", self.text_gap)
        form.addRow("Espessura", self.line_thickness)
        form.addRow("Prolongamento", self.overhang)
        form.addRow("Recuo", self.extension_gap)
        form.addRow("Terminal", self.terminal)
        form.addRow("Tamanho terminal", self.terminal_size)
        form.addRow("Posição terminal", self.placement)
        form.addRow("Ângulo", self.terminal_angle)
        form.addRow("Opções", self.bold)
        form.addRow("", self.italic)
        form.addRow("", self.mask)
        form.addRow("Cor", self.annotation_color)
        right_layout.addWidget(form_box)

        preview_box = group("Preview 2D")
        preview_layout = QtWidgets.QVBoxLayout(preview_box)
        self.preview = PreviewWidget()
        preview_layout.addWidget(self.preview)
        preview_controls = QtWidgets.QHBoxLayout()
        self.zoom = QtWidgets.QComboBox()
        for label, value in (("50%", 0.5), ("100%", 1.0), ("200%", 2.0)):
            self.zoom.addItem(label, value)
        self.dark = QtWidgets.QCheckBox("Fundo escuro")
        self.dark.setChecked(True)
        self.zoom.currentIndexChanged.connect(self.update_preview)
        self.dark.toggled.connect(self.update_preview)
        preview_controls.addWidget(self.zoom)
        preview_controls.addWidget(self.dark)
        preview_controls.addStretch(1)
        preview_layout.addLayout(preview_controls)
        right_layout.addWidget(preview_box)

        actions = QtWidgets.QHBoxLayout()
        actions.addWidget(button("Atualizar lista", self.refresh))
        actions.addWidget(button("Salvar estilo", self.save_style, primary=True))
        actions.addWidget(button("Aplicar selecionadas", self.apply_selected))
        actions.addWidget(button("Atualizar todas", self.apply_all))
        right_layout.addLayout(actions)
        split.addWidget(right)
        split.setSizes([210, 600])

        self.status = message_label()
        root.addWidget(self.status)

        self._connect_dirty_signals()

    def _connect_dirty_signals(self) -> None:
        # Conecte cada sinal explicitamente. Alguns SignalInstance de Qt têm
        # conversão booleana dependente da versão; encadear ``or`` neles pode
        # escolher o sinal errado ou falhar antes mesmo de a janela aparecer.
        signals = (
            (self.name, "textChanged"),
            (self.font, "currentFontChanged"),
            (self.font_size, "valueChanged"),
            (self.tracking, "valueChanged"),
            (self.text_gap, "valueChanged"),
            (self.line_thickness, "valueChanged"),
            (self.overhang, "valueChanged"),
            (self.extension_gap, "valueChanged"),
            (self.terminal, "currentIndexChanged"),
            (self.terminal_size, "valueChanged"),
            (self.placement, "currentIndexChanged"),
            (self.terminal_angle, "valueChanged"),
            (self.bold, "toggled"),
            (self.italic, "toggled"),
            (self.mask, "toggled"),
        )
        for widget, signal_name in signals:
            signal = getattr(widget, signal_name, None)
            if signal is not None:
                signal.connect(lambda *_args: self.update_preview())

    def refresh(self) -> None:
        try:
            self.load_styles(self.bridge.styles())
            set_message(self.status, "Estilos atualizados.")
        except BridgeError as exc:
            set_message(self.status, exc.message, error=True)

    def load_styles(self, styles: List[StyleSnapshot]) -> None:
        self._styles = list(styles)
        current_id = self._current.style_id if self._current else None
        self._loading = True
        self.list_widget.clear()
        for item in self._styles:
            suffix = " · %d em uso" % item.in_use if item.in_use else ""
            self.list_widget.addItem(item.name + suffix)
        self._loading = False
        row = next((idx for idx, item in enumerate(self._styles) if item.style_id == current_id), 0)
        if self._styles:
            self.list_widget.setCurrentRow(row)
        else:
            self._current = None
            self._clear_form()

    def _select_row(self, row: int) -> None:
        if self._loading or row < 0 or row >= len(self._styles):
            return
        self._current = self._styles[row]
        self._load_form(self._current)

    def _set_combo(self, combo: QtWidgets.QComboBox, value: str) -> None:
        index = combo.findData(value)
        if index >= 0:
            combo.setCurrentIndex(index)

    def _load_form(self, style: StyleSnapshot) -> None:
        self._loading = True
        self.name.setText(style.name)
        self.font.setCurrentFont(QtGui.QFont(style.font_name))
        self.font_size.setValue(style.font_size)
        self.tracking.setValue(style.tracking)
        self.text_gap.setValue(style.text_gap)
        self.line_thickness.setValue(style.line_thickness)
        self.overhang.setValue(style.extension_overhang)
        self.extension_gap.setValue(style.extension_gap)
        self._set_combo(self.terminal, style.terminal_type)
        self.terminal_size.setValue(style.terminal_size)
        self._set_combo(self.placement, style.terminal_placement)
        self.terminal_angle.setValue(style.terminal_angle)
        self.bold.setChecked(style.bold)
        self.italic.setChecked(style.italic)
        self.mask.setChecked(style.text_mask_enabled)
        self.annotation_color.setProperty("colorText", style.annotation_color)
        self.annotation_color.setStyleSheet("background: rgb(%s);" % style.annotation_color)
        self._loading = False
        self.update_preview()

    def _clear_form(self) -> None:
        self.name.clear()
        self.preview.set_model(None, True, 1.0)

    def _edited_style(self) -> Optional[StyleSnapshot]:
        if self._current is None:
            return None
        return replace(self._current, name=self.name.text().strip() or self._current.name, font_name=self.font.currentFont().family(), font_size=self.font_size.value(), bold=self.bold.isChecked(), italic=self.italic.isChecked(), tracking=self.tracking.value(), text_gap=self.text_gap.value(), line_thickness=self.line_thickness.value(), extension_overhang=self.overhang.value(), extension_gap=self.extension_gap.value(), terminal_type=str(self.terminal.currentData()), terminal_size=self.terminal_size.value(), text_mask_enabled=self.mask.isChecked(), annotation_color=str(self.annotation_color.property("colorText") or self._current.annotation_color), terminal_placement=str(self.placement.currentData()), terminal_angle=self.terminal_angle.value())

    def update_preview(self) -> None:
        if self._loading:
            return
        self.preview.set_model(self._edited_style(), self.dark.isChecked(), float(self.zoom.currentData() or 1.0))

    def choose_color(self) -> None:
        current = color_text_to_qcolor(str(self.annotation_color.property("colorText") or "245,245,245"))
        color = QtWidgets.QColorDialog.getColor(current, self, "Cor da cota")
        if color.isValid():
            text = qcolor_to_text(color)
            self.annotation_color.setProperty("colorText", text)
            self.annotation_color.setStyleSheet("background: rgb(%s);" % text)
            self.update_preview()

    def save_style(self) -> None:
        style = self._edited_style()
        if style is None:
            return
        try:
            count = self.bridge.save_style(style)
            self.refresh()
            set_message(self.status, "Estilo salvo; %d cota(s) reconstruída(s)." % count)
        except BridgeError as exc:
            set_message(self.status, exc.message, error=True)

    def new_style(self) -> None:
        base = self._current.style_id if self._current else "default"
        name, accepted = QtWidgets.QInputDialog.getText(self, "Novo estilo", "Nome:")
        if not accepted or not name.strip():
            return
        try:
            created = self.bridge.new_style(base, name.strip())
            self.refresh()
            row = next((idx for idx, item in enumerate(self._styles) if item.style_id == created.style_id), -1)
            if row >= 0:
                self.list_widget.setCurrentRow(row)
            set_message(self.status, "Novo estilo criado.")
        except BridgeError as exc:
            set_message(self.status, exc.message, error=True)

    def duplicate_style(self) -> None:
        self.new_style()

    def delete_style(self) -> None:
        if self._current is None or self._current.style_id == "default":
            set_message(self.status, "O estilo padrão não pode ser excluído.", error=True)
            return
        answer = QtWidgets.QMessageBox.question(self, "Excluir estilo", "Excluir este estilo?", QtWidgets.QMessageBox.StandardButton.Yes | QtWidgets.QMessageBox.StandardButton.No)
        if answer != QtWidgets.QMessageBox.StandardButton.Yes:
            return
        try:
            self.bridge.delete_style(self._current.style_id)
            self._current = None
            self.refresh()
            set_message(self.status, "Estilo excluído.")
        except BridgeError as exc:
            set_message(self.status, exc.message, error=True)

    def apply_selected(self) -> None:
        if self._current is None:
            return
        try:
            count = self.bridge.apply_style(self._current.style_id, False)
            set_message(self.status, "%d cota(s) selecionada(s) atualizada(s)." % count)
        except BridgeError as exc:
            set_message(self.status, exc.message, error=True)

    def apply_all(self) -> None:
        if self._current is None:
            return
        try:
            count = self.bridge.apply_style(self._current.style_id, True)
            set_message(self.status, "%d cota(s) atualizada(s)." % count)
        except BridgeError as exc:
            set_message(self.status, exc.message, error=True)
