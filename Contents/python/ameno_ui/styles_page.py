"""Qt style editor rebuilt independently from the former WPF presentation."""

from __future__ import annotations

from typing import Dict, List, Optional

from .bridge import BridgeError, UiBridge
from .common import button, group, message_label, set_bridge_error, set_message
from .components import Disclosure, PageHeader, SectionHeading
from .models import StyleSnapshot
from .parameter_control import ParameterControl, style_parameter_specs
from .qt_compat import QtCore, QtGui, QtWidgets
from .style_draft import StyleDraft


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
        bg = QtGui.QColor("#121212" if self._dark else "#E8E8E0")
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
        self.setObjectName("StylesPage")
        self.bridge = bridge
        self._styles: List[StyleSnapshot] = []
        self._current: Optional[StyleSnapshot] = None
        self._loading = False
        # A local draft exists before the style library or the scene is read.
        # It is the only source used by the form and the 2D preview.
        self.draft = StyleDraft(parent=self)

        root = QtWidgets.QVBoxLayout(self)
        root.setContentsMargins(30, 26, 30, 30)
        root.setSpacing(14)
        root.addWidget(
            PageHeader(
                "Aparência",
                "Defina como as cotas serão lidas no desenho. A prévia é local e não toca a viewport.",
                "ESTILOS",
            )
        )

        split = QtWidgets.QSplitter(QtCore.Qt.Orientation.Horizontal)
        root.addWidget(split, 1)

        left = QtWidgets.QFrame()
        left.setObjectName("Card")
        left_layout = QtWidgets.QVBoxLayout(left)
        left_layout.addWidget(SectionHeading("Estilos salvos", "Selecione um estilo para editar."))
        self.list_widget = QtWidgets.QListWidget()
        self.list_widget.setMinimumWidth(190)
        self.list_widget.currentRowChanged.connect(self._select_row)
        left_layout.addWidget(self.list_widget, 1)
        left_buttons = QtWidgets.QHBoxLayout()
        self.new_button = button("Novo estilo", self.new_style)
        self.style_more = QtWidgets.QToolButton()
        self.style_more.setText("Mais  ···")
        self.style_more.setPopupMode(QtWidgets.QToolButton.ToolButtonPopupMode.InstantPopup)
        self.style_menu = QtWidgets.QMenu(self.style_more)
        self.refresh_action = self.style_menu.addAction("Atualizar lista")
        self.duplicate_action = self.style_menu.addAction("Duplicar estilo")
        self.delete_action = self.style_menu.addAction("Excluir estilo…")
        self.style_more.setMenu(self.style_menu)
        self.refresh_action.triggered.connect(self.refresh)
        self.duplicate_action.triggered.connect(self.duplicate_style)
        self.delete_action.triggered.connect(self.delete_style)
        left_buttons.addWidget(self.new_button, 1)
        left_buttons.addWidget(self.style_more)
        left_layout.addLayout(left_buttons)
        split.addWidget(left)

        right = QtWidgets.QWidget()
        right_layout = QtWidgets.QVBoxLayout(right)
        self.name = QtWidgets.QLineEdit()
        self.font = QtWidgets.QFontComboBox()
        controls = {spec.field_name: ParameterControl(spec) for spec in style_parameter_specs()}
        self.font_size = controls["font_size"]
        self.tracking = controls["tracking"]
        self.text_gap = controls["text_gap"]
        self.line_thickness = controls["line_thickness"]
        self.overhang = controls["extension_overhang"]
        self.extension_gap = controls["extension_gap"]
        self.terminal_size = controls["terminal_size"]
        self.terminal_angle = controls["terminal_angle"]
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

        preview_box = group("Prévia 2D")
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

        text_box = group("Texto")
        text_form = QtWidgets.QFormLayout(text_box)
        text_form.addRow("Nome do estilo", self.name)
        text_form.addRow("Fonte", self.font)
        text_form.addRow("Tamanho", self.font_size)
        text_form.addRow("Espaçamento", self.tracking)
        text_form.addRow("Distância da linha", self.text_gap)
        text_form.addRow("Opções", self.bold)
        text_form.addRow("", self.italic)
        text_form.addRow("", self.mask)
        text_form.addRow("Cor", self.annotation_color)
        right_layout.addWidget(text_box)

        advanced_host = QtWidgets.QWidget()
        advanced_host.setObjectName("TransparentHost")
        advanced_layout = QtWidgets.QHBoxLayout(advanced_host)
        advanced_layout.setContentsMargins(0, 0, 0, 0)
        line_box = group("Linhas")
        line_form = QtWidgets.QFormLayout(line_box)
        line_form.addRow("Espessura", self.line_thickness)
        line_form.addRow("Prolongamento", self.overhang)
        line_form.addRow("Recuo", self.extension_gap)
        terminal_box = group("Terminais")
        terminal_form = QtWidgets.QFormLayout(terminal_box)
        terminal_form.addRow("Tipo", self.terminal)
        terminal_form.addRow("Tamanho", self.terminal_size)
        terminal_form.addRow("Posição", self.placement)
        terminal_form.addRow("Ângulo", self.terminal_angle)
        advanced_layout.addWidget(line_box, 1)
        advanced_layout.addWidget(terminal_box, 1)
        self.advanced = Disclosure("Ajustes de linha e terminais", advanced_host, expanded=False)
        right_layout.addWidget(self.advanced)

        actions = QtWidgets.QHBoxLayout()
        self.save_button = button("Salvar alterações", self.save_style, primary=True)
        self.apply_button = QtWidgets.QToolButton()
        self.apply_button.setText("Aplicar estilo  ▾")
        self.apply_button.setMinimumHeight(40)
        self.apply_button.setPopupMode(QtWidgets.QToolButton.ToolButtonPopupMode.InstantPopup)
        self.apply_menu = QtWidgets.QMenu(self.apply_button)
        self.apply_selected_action = self.apply_menu.addAction("Aplicar às cotas selecionadas")
        self.apply_all_action = self.apply_menu.addAction("Aplicar a todas as cotas")
        self.apply_button.setMenu(self.apply_menu)
        self.apply_selected_action.triggered.connect(self.apply_selected)
        self.apply_all_action.triggered.connect(self.apply_all)
        actions.addWidget(self.save_button, 1)
        actions.addWidget(self.apply_button)
        right_layout.addLayout(actions)
        split.addWidget(right)
        split.setSizes([210, 600])

        self.status = message_label()
        self.status.setText("Selecione um estilo ou atualize a lista para começar.")
        root.addWidget(self.status)

        self._connect_dirty_signals()
        self._load_form(self.draft.to_snapshot())

    def _connect_dirty_signals(self) -> None:
        # Conecte cada sinal explicitamente. Alguns SignalInstance de Qt têm
        # conversão booleana dependente da versão; encadear ``or`` neles pode
        # escolher o sinal errado ou falhar antes mesmo de a janela aparecer.
        signals = (
            (self.name, "textChanged", "name"),
            (self.font, "currentFontChanged", "font_name"),
            (self.font_size, "valueChanged", "font_size"),
            (self.tracking, "valueChanged", "tracking"),
            (self.text_gap, "valueChanged", "text_gap"),
            (self.line_thickness, "valueChanged", "line_thickness"),
            (self.overhang, "valueChanged", "extension_overhang"),
            (self.extension_gap, "valueChanged", "extension_gap"),
            (self.terminal, "currentIndexChanged", "terminal_type"),
            (self.terminal_size, "valueChanged", "terminal_size"),
            (self.placement, "currentIndexChanged", "terminal_placement"),
            (self.terminal_angle, "valueChanged", "terminal_angle"),
            (self.bold, "toggled", "bold"),
            (self.italic, "toggled", "italic"),
            (self.mask, "toggled", "text_mask_enabled"),
        )
        for widget, signal_name, field_name in signals:
            signal = getattr(widget, signal_name, None)
            if signal is not None:
                signal.connect(
                    lambda *_args, source=widget, field=field_name: self._form_changed(source, field)
                )
        self.draft.changed.connect(lambda *_args: self.update_preview())

    def _form_value(self, widget: QtWidgets.QWidget, field_name: str):
        if field_name == "font_name":
            return widget.currentFont().family()
        if field_name in ("terminal_type", "terminal_placement"):
            return str(widget.currentData())
        if field_name in ("bold", "italic", "text_mask_enabled"):
            return widget.isChecked()
        if field_name == "annotation_color":
            return str(self.annotation_color.property("colorText") or "245,245,245")
        if hasattr(widget, "value"):
            return widget.value()
        return widget.text()

    def _form_changed(self, widget: QtWidgets.QWidget, field_name: str) -> None:
        if self._loading:
            return
        self.draft.set_value(field_name, self._form_value(widget, field_name))

    def refresh(self) -> None:
        try:
            self.load_styles(self.bridge.styles())
            set_message(self.status, "Estilos atualizados.")
        except BridgeError as exc:
            set_bridge_error(self.status, exc, "Não foi possível atualizar os estilos.")

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
        self.draft.load(style)
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
        self._load_form(StyleSnapshot("default", "Arquitetônico"))

    def _edited_style(self) -> StyleSnapshot:
        return self.draft.to_snapshot()

    def update_preview(self) -> None:
        if self._loading:
            return
        self.preview.set_model(self.draft.to_snapshot(), self.dark.isChecked(), float(self.zoom.currentData() or 1.0))

    def choose_color(self) -> None:
        current = color_text_to_qcolor(str(self.annotation_color.property("colorText") or "245,245,245"))
        color = QtWidgets.QColorDialog.getColor(current, self, "Cor da cota")
        if color.isValid():
            text = qcolor_to_text(color)
            self.annotation_color.setProperty("colorText", text)
            self.annotation_color.setStyleSheet("background: rgb(%s);" % text)
            self.draft.set_value("annotation_color", text)

    def save_style(self) -> None:
        style = self._edited_style()
        if style is None:
            return
        try:
            count = self.bridge.save_style(style)
            self.refresh()
            set_message(self.status, "Estilo salvo; %d cota(s) reconstruída(s)." % count)
        except BridgeError as exc:
            set_bridge_error(self.status, exc, "Não foi possível salvar o estilo.")

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
            set_bridge_error(self.status, exc, "Não foi possível criar o estilo.")

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
            set_bridge_error(self.status, exc, "Não foi possível excluir o estilo.")

    def apply_selected(self) -> None:
        if self._current is None:
            return
        try:
            count = self.bridge.apply_style(self._current.style_id, False)
            set_message(self.status, "%d cota(s) selecionada(s) atualizada(s)." % count)
        except BridgeError as exc:
            set_bridge_error(self.status, exc, "Não foi possível aplicar o estilo à seleção.")

    def apply_all(self) -> None:
        if self._current is None:
            return
        try:
            count = self.bridge.apply_style(self._current.style_id, True)
            set_message(self.status, "%d cota(s) atualizada(s)." % count)
        except BridgeError as exc:
            set_bridge_error(self.status, exc, "Não foi possível aplicar o estilo às cotas.")
