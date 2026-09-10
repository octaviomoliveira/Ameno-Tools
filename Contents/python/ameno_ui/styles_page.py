"""Qt style editor rebuilt independently from the former WPF presentation."""

from __future__ import annotations

from typing import Dict, List, Optional

from .bridge import BridgeError, UiBridge
from .common import button, set_bridge_error, set_message
from .components import CollapsibleSection, ColorControl, PageHeader
from .dimension_preview import PreviewGeometry, PreviewTerminal, build_preview_geometry
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
        self.setMinimumHeight(150)
        self._style: StyleSnapshot = StyleSnapshot("default", "Arquitetônico")
        self._dark = True
        self._zoom = 1.0

    def set_model(self, style: Optional[StyleSnapshot], dark: bool, zoom: float) -> None:
        self._style = style or StyleSnapshot("default", "Arquitetônico")
        self._dark = dark
        self._zoom = zoom
        self.update()

    def paintEvent(self, event) -> None:  # noqa: N802 - Qt API
        painter = QtGui.QPainter(self)
        painter.setRenderHint(QtGui.QPainter.RenderHint.Antialiasing, True)
        bg = QtGui.QColor("#121212" if self._dark else "#E8E8E0")
        painter.fillRect(self.rect(), bg)
        geometry = build_preview_geometry(self._style, self.rect(), self._zoom)
        line_color = color_text_to_qcolor(geometry.line_color)
        text_color = color_text_to_qcolor(geometry.text.color)
        if not line_color.isValid():
            line_color = QtGui.QColor("#f3f4f6" if self._dark else "#1f2937")
        if not text_color.isValid():
            text_color = line_color
        pen = QtGui.QPen(line_color)
        pen.setWidthF(geometry.line_thickness_px)
        painter.setPen(pen)
        for segment in geometry.all_segments:
            painter.drawLine(QtCore.QPointF(*segment.start), QtCore.QPointF(*segment.end))
        for terminal in geometry.terminals:
            self._paint_terminal(painter, terminal, line_color)
        font = QtGui.QFont(geometry.text.font_name)
        font.setPixelSize(max(1, round(geometry.text.font_size_px)))
        font.setBold(geometry.text.bold)
        font.setItalic(geometry.text.italic)
        try:
            font.setLetterSpacing(QtGui.QFont.SpacingType.AbsoluteSpacing, geometry.text.tracking_px)
        except (AttributeError, TypeError):
            pass
        painter.setFont(font)
        if geometry.text.mask_rect is not None:
            x, y, width, height = geometry.text.mask_rect
            painter.fillRect(QtCore.QRectF(x, y, width, height), bg)
        painter.setPen(text_color)
        painter.drawText(QtCore.QPointF(*geometry.text.baseline), geometry.text.value)
        painter.end()

    @staticmethod
    def _paint_terminal(painter: QtGui.QPainter, terminal: PreviewTerminal, color: QtGui.QColor) -> None:
        painter.setBrush(QtCore.Qt.BrushStyle.NoBrush)
        if terminal.kind == "dot":
            painter.setBrush(color)
            painter.drawEllipse(QtCore.QPointF(*terminal.anchor), terminal.radius, terminal.radius)
        elif terminal.kind == "arrowClosed":
            painter.setBrush(color)
            painter.drawPolygon(QtGui.QPolygonF([QtCore.QPointF(*point) for point in terminal.points]))
        elif terminal.points:
            for index in range(0, len(terminal.points) - 1, 2):
                painter.drawLine(
                    QtCore.QPointF(*terminal.points[index]),
                    QtCore.QPointF(*terminal.points[index + 1]),
                )


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
        root.setContentsMargins(24, 20, 24, 18)
        root.setSpacing(10)
        root.addWidget(PageHeader("Estilo", "Ajuste a aparência das cotas e aplique o estilo.", "ESTILO"))

        self.style_card = QtWidgets.QWidget()
        self.style_card.setObjectName("TransparentHost")
        style_layout = QtWidgets.QHBoxLayout(self.style_card)
        style_layout.setContentsMargins(0, 0, 0, 0)
        style_layout.setSpacing(8)
        self.style_selector = QtWidgets.QComboBox()
        self.style_selector.setAccessibleName("Estilo atual")
        self.style_selector.addItem("Arquitetônico", "default")
        self.style_selector.currentIndexChanged.connect(self._select_combo)
        style_layout.addWidget(self.style_selector, 1)
        self.new_button = button("Novo estilo", self.new_style)
        self.new_button.setMinimumWidth(118)
        style_layout.addWidget(self.new_button)
        self.style_more = QtWidgets.QToolButton()
        self.style_more.setText("···")
        self.style_more.setAccessibleName("Mais ações de estilo")
        self.style_more.setPopupMode(QtWidgets.QToolButton.ToolButtonPopupMode.InstantPopup)
        self.style_menu = QtWidgets.QMenu(self.style_more)
        self.refresh_action = self.style_menu.addAction("Atualizar estilos")
        self.duplicate_action = self.style_menu.addAction("Duplicar estilo")
        self.delete_action = self.style_menu.addAction("Excluir estilo…")
        self.style_more.setMenu(self.style_menu)
        self.refresh_action.triggered.connect(self.refresh)
        self.duplicate_action.triggered.connect(self.duplicate_style)
        self.delete_action.triggered.connect(self.delete_style)
        style_layout.addWidget(self.style_more)
        root.addWidget(self.style_card)

        # Kept as a hidden compatibility index; the visible selector is the
        # compact control above.
        self.list_widget = QtWidgets.QListWidget(self)
        self.list_widget.setVisible(False)
        self.list_widget.currentRowChanged.connect(self._select_row)

        self.name = QtWidgets.QLineEdit()
        self.font = QtWidgets.QFontComboBox()
        controls = {spec.field_name: ParameterControl(spec) for spec in style_parameter_specs()}
        for control in controls.values():
            # The technical editor keeps the required slider + precise value
            # visible. Defaults remain encoded in each control, while the
            # narrow column avoids a fifth competing action per row.
            control.reset_button.setVisible(False)
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
        self.annotation_color = ColorControl("Editar cor das cotas")
        self.annotation_color.edit_requested.connect(self.choose_color)

        preview_box = QtWidgets.QFrame()
        preview_box.setObjectName("PreviewPanel")
        preview_layout = QtWidgets.QVBoxLayout(preview_box)
        preview_layout.setContentsMargins(14, 12, 14, 12)
        preview_layout.setSpacing(8)
        preview_title = QtWidgets.QLabel("Prévia 2D")
        preview_title.setObjectName("EditorSectionTitle")
        preview_layout.addWidget(preview_title)
        self.preview = PreviewWidget()
        preview_layout.addWidget(self.preview, 1)
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
        self.preview_box = preview_box

        text_content = QtWidgets.QWidget()
        text_form = QtWidgets.QFormLayout(text_content)
        text_form.setContentsMargins(14, 8, 14, 12)
        text_form.setHorizontalSpacing(12)
        text_form.setVerticalSpacing(8)
        text_form.setFieldGrowthPolicy(QtWidgets.QFormLayout.FieldGrowthPolicy.AllNonFixedFieldsGrow)
        text_form.addRow("Nome do estilo", self.name)
        text_form.addRow("Fonte", self.font)
        text_form.addRow("Tamanho", self.font_size)
        text_form.addRow("Espaçamento", self.tracking)
        text_form.addRow("Distância da linha", self.text_gap)
        text_options = QtWidgets.QHBoxLayout()
        text_options.addWidget(self.bold)
        text_options.addWidget(self.italic)
        text_options.addStretch(1)
        text_form.addRow("Opções", text_options)
        self.text_section = CollapsibleSection("Texto", text_content, expanded=True)
        self.text_box = self.text_section

        line_content = QtWidgets.QWidget()
        line_form = QtWidgets.QFormLayout(line_content)
        line_form.setContentsMargins(14, 8, 14, 12)
        line_form.setHorizontalSpacing(12)
        line_form.setVerticalSpacing(8)
        line_form.addRow("Espessura", self.line_thickness)
        line_form.addRow("Prolongamento", self.overhang)
        line_form.addRow("Recuo", self.extension_gap)
        self.lines_section = CollapsibleSection("Linhas", line_content, expanded=False)

        terminal_content = QtWidgets.QWidget()
        terminal_form = QtWidgets.QFormLayout(terminal_content)
        terminal_form.setContentsMargins(14, 8, 14, 12)
        terminal_form.setHorizontalSpacing(12)
        terminal_form.setVerticalSpacing(8)
        terminal_form.addRow("Tipo", self.terminal)
        terminal_form.addRow("Tamanho", self.terminal_size)
        terminal_form.addRow("Posição", self.placement)
        terminal_form.addRow("Ângulo", self.terminal_angle)
        self.terminals_section = CollapsibleSection("Terminais", terminal_content, expanded=False)

        color_content = QtWidgets.QWidget()
        color_form = QtWidgets.QFormLayout(color_content)
        color_form.setContentsMargins(14, 8, 14, 12)
        color_form.setHorizontalSpacing(12)
        color_form.setVerticalSpacing(8)
        color_form.addRow("Cor das cotas", self.annotation_color)
        color_form.addRow("Texto", self.mask)
        self.colors_section = CollapsibleSection("Cores", color_content, expanded=True)

        controls_host = QtWidgets.QWidget()
        controls_host.setObjectName("TransparentHost")
        controls_layout = QtWidgets.QVBoxLayout(controls_host)
        controls_layout.setContentsMargins(0, 0, 4, 0)
        controls_layout.setSpacing(8)
        controls_layout.addWidget(self.text_section)
        controls_layout.addWidget(self.lines_section)
        controls_layout.addWidget(self.terminals_section)
        controls_layout.addWidget(self.colors_section)
        controls_layout.addStretch(1)
        self.controls_scroll = QtWidgets.QScrollArea()
        self.controls_scroll.setObjectName("StyleControlsScroll")
        self.controls_scroll.setWidgetResizable(True)
        self.controls_scroll.setFrameShape(QtWidgets.QFrame.Shape.NoFrame)
        self.controls_scroll.setHorizontalScrollBarPolicy(QtCore.Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        self.controls_scroll.setWidget(controls_host)

        self.editor = QtWidgets.QWidget()
        self.editor.setObjectName("StyleWorkspace")
        self.workspace_layout = QtWidgets.QBoxLayout(QtWidgets.QBoxLayout.Direction.LeftToRight, self.editor)
        self.workspace_layout.setContentsMargins(0, 0, 0, 0)
        self.workspace_layout.setSpacing(10)
        self.workspace_layout.addWidget(self.controls_scroll, 5)
        self.workspace_layout.addWidget(self.preview_box, 6)
        root.addWidget(self.editor, 1)
        self._workspace_mode = "wide"
        self.advanced = self.lines_section

        self.footer = QtWidgets.QFrame()
        self.footer.setObjectName("StyleFooter")
        actions = QtWidgets.QHBoxLayout(self.footer)
        actions.setContentsMargins(12, 9, 12, 9)
        actions.setSpacing(10)
        self.dirty_dot = QtWidgets.QFrame()
        self.dirty_dot.setObjectName("DirtyDot")
        self.dirty_dot.setFixedSize(11, 11)
        actions.addWidget(self.dirty_dot)
        self.status = QtWidgets.QLabel("Estilo sincronizado")
        self.status.setObjectName("FooterStatus")
        self.status.setWordWrap(True)
        actions.addWidget(self.status, 1)
        self.save_button = button("Salvar estilo", self.save_style)
        self.save_button.setMinimumWidth(118)
        self.apply_button = button("Aplicar", self.apply_selected, primary=True)
        self.apply_button.setAccessibleName("Aplicar estilo")
        self.apply_button.setMinimumWidth(130)
        self.style_menu.addSeparator()
        self.apply_menu = self.style_menu
        self.apply_selected_action = self.style_menu.addAction("Aplicar às cotas selecionadas")
        self.apply_all_action = self.style_menu.addAction("Aplicar a todas as cotas")
        self.apply_selected_action.triggered.connect(self.apply_selected)
        self.apply_all_action.triggered.connect(self.apply_all)
        actions.addWidget(self.save_button)
        actions.addWidget(self.apply_button)
        root.addWidget(self.footer)

        self._connect_dirty_signals()
        self.draft.dirty_changed.connect(self._draft_state_changed)
        self._load_form(self.draft.to_snapshot())
        self._draft_state_changed(False)
        self._apply_workspace_mode()

    def sizeHint(self) -> QtCore.QSize:  # noqa: N802 - Qt API
        # The outer host must size this fixed shell to its viewport. Only the
        # dedicated controls_scroll owns content-driven vertical growth.
        return QtCore.QSize(720, 500)

    def minimumSizeHint(self) -> QtCore.QSize:  # noqa: N802 - Qt API
        return QtCore.QSize(380, 400)

    def resizeEvent(self, event) -> None:  # noqa: N802 - Qt API
        super().resizeEvent(event)
        self._apply_workspace_mode()

    def _apply_workspace_mode(self) -> None:
        compact = self.width() < 720
        mode = "compact" if compact else "wide"
        if mode == self._workspace_mode and self.editor.isVisible():
            return
        self._workspace_mode = mode
        self.workspace_layout.setDirection(
            QtWidgets.QBoxLayout.Direction.TopToBottom
            if compact
            else QtWidgets.QBoxLayout.Direction.LeftToRight
        )
        if compact:
            self.preview_box.setMinimumWidth(0)
            self.preview_box.setMinimumHeight(170)
            self.preview_box.setMaximumHeight(190)
            self.workspace_layout.insertWidget(0, self.preview_box)
            self.workspace_layout.setStretch(0, 0)
            self.workspace_layout.setStretch(1, 1)
        else:
            self.preview_box.setMinimumWidth(310)
            self.preview_box.setMinimumHeight(0)
            self.preview_box.setMaximumHeight(16777215)
            self.workspace_layout.insertWidget(0, self.controls_scroll, 5)
            self.workspace_layout.insertWidget(1, self.preview_box, 6)
            self.workspace_layout.setStretch(0, 5)
            self.workspace_layout.setStretch(1, 6)

    def _select_combo(self, row: int) -> None:
        if self._loading or row < 0:
            return
        self.list_widget.setCurrentRow(row)

    def _draft_state_changed(self, dirty: bool) -> None:
        if dirty:
            self.status.setText("Alterações não salvas")
            self.dirty_dot.setStyleSheet("background-color: #E5B567; border-radius: 5px;")
        elif not self.status.property("error"):
            self.status.setText("Estilo sincronizado")
            self.dirty_dot.setStyleSheet("background-color: #75B798; border-radius: 5px;")

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
        self.style_selector.clear()
        for item in self._styles:
            suffix = " · %d em uso" % item.in_use if item.in_use else ""
            self.list_widget.addItem(item.name + suffix)
            self.style_selector.addItem(item.name, item.style_id)
        self._loading = False
        row = next((idx for idx, item in enumerate(self._styles) if item.style_id == current_id), 0)
        if self._styles:
            self.list_widget.setCurrentRow(row)
        else:
            self._current = None
            blocker = QtCore.QSignalBlocker(self.style_selector)
            self.style_selector.addItem("Arquitetônico", "default")
            del blocker
            self._clear_form()

    def _select_row(self, row: int) -> None:
        if self._loading or row < 0 or row >= len(self._styles):
            return
        self._current = self._styles[row]
        blocker = QtCore.QSignalBlocker(self.style_selector)
        self.style_selector.setCurrentIndex(row)
        del blocker
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
        self.annotation_color.set_color_text(style.annotation_color)
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
        current = color_text_to_qcolor(self.annotation_color.color_text())
        color = QtWidgets.QColorDialog.getColor(current, self, "Cor da cota")
        if color.isValid():
            text = qcolor_to_text(color)
            self.annotation_color.set_color_text(text)
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
