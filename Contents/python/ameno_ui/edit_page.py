"""Selection review using one explicit audit snapshot per refresh."""

from __future__ import annotations

from typing import List, Optional

from .bridge import BridgeError, UiBridge
from .common import button, group, message_label, set_bridge_error, set_message
from .components import PageHeader, SectionHeading
from .models import AuditSnapshot, StyleSnapshot
from .qt_compat import QtCore, QtWidgets


class EditPage(QtWidgets.QWidget):
    def __init__(self, bridge: UiBridge) -> None:
        super().__init__()
        self.setObjectName("EditPage")
        self.bridge = bridge
        self._audit: Optional[AuditSnapshot] = None
        root = QtWidgets.QVBoxLayout(self)
        root.setContentsMargins(30, 26, 30, 30)
        root.setSpacing(14)
        root.addWidget(
            PageHeader(
                "Revisar",
                "Selecione uma cota na viewport e atualize a leitura para revisar ou corrigir o valor exibido.",
                "EDIÇÃO",
            )
        )

        refresh_row = QtWidgets.QHBoxLayout()
        refresh_row.addStretch(1)
        self.refresh_button = button("Ler seleção atual", self.refresh)
        refresh_row.addWidget(self.refresh_button)
        root.addLayout(refresh_row)

        self.selection_stack = QtWidgets.QStackedWidget()
        self.selection_stack.setObjectName("SelectionStack")

        empty = QtWidgets.QFrame()
        empty.setObjectName("Card")
        empty_layout = QtWidgets.QVBoxLayout(empty)
        empty_layout.setContentsMargins(24, 32, 24, 32)
        empty_layout.addWidget(SectionHeading("Nenhuma cota carregada", "Selecione uma cota Ameno no 3ds Max e clique em Ler seleção atual."))
        empty_layout.addWidget(QtWidgets.QLabel("A interface não monitora a viewport em segundo plano."))
        empty_layout.addStretch(1)
        self.selection_stack.addWidget(empty)

        selected = QtWidgets.QWidget()
        selected_layout = QtWidgets.QVBoxLayout(selected)
        selected_layout.setContentsMargins(0, 0, 0, 0)
        selected_layout.setSpacing(12)
        info_box = group("Leitura da cota")
        info = QtWidgets.QFormLayout(info_box)
        self.dimension_id = QtWidgets.QLabel("—")
        self.dimension_id.setObjectName("Meta")
        self.measured = QtWidgets.QLabel("—")
        self.displayed = QtWidgets.QLabel("—")
        self.delta = QtWidgets.QLabel("—")
        self.anchor = QtWidgets.QLabel("—")
        self.orphan = QtWidgets.QLabel("—")
        for label, widget in (
            ("ID", self.dimension_id),
            ("Medido na cena", self.measured),
            ("Exibido", self.displayed),
            ("Diferença", self.delta),
            ("Referências", self.anchor),
            ("Estado", self.orphan),
        ):
            widget.setTextInteractionFlags(QtCore.Qt.TextInteractionFlag.TextSelectableByMouse)
            info.addRow(label, widget)
        selected_layout.addWidget(info_box)

        edit_box = group("Valor exibido")
        edit_layout = QtWidgets.QVBoxLayout(edit_box)
        mode_row = QtWidgets.QFormLayout()
        self.mode = QtWidgets.QComboBox()
        for label, value in (
            ("Usar o valor medido", "measured"),
            ("Arredondar o valor", "rounded"),
            ("Informar outro número", "manualNumeric"),
            ("Escrever um texto", "manualText"),
        ):
            self.mode.addItem(label, value)
        mode_row.addRow("Como exibir", self.mode)
        edit_layout.addLayout(mode_row)

        self.override_stack = QtWidgets.QStackedWidget()
        measured_page = QtWidgets.QLabel("O texto acompanhará automaticamente a medida real da cena.")
        measured_page.setObjectName("Muted")
        measured_page.setWordWrap(True)
        self.override_stack.addWidget(measured_page)
        self.rounding = QtWidgets.QDoubleSpinBox()
        self.rounding.setRange(0, 1000000)
        self.rounding.setDecimals(2)
        self.rounding.setSuffix(" mm")
        self.override_stack.addWidget(self._field_page("Arredondar em passos de", self.rounding))
        self.manual_value = QtWidgets.QLineEdit()
        self.manual_value.setPlaceholderText("Ex.: 3500")
        self.override_stack.addWidget(self._field_page("Valor numérico", self.manual_value))
        self.manual_text = QtWidgets.QLineEdit()
        self.manual_text.setPlaceholderText("Ex.: verificar em obra")
        self.override_stack.addWidget(self._field_page("Texto da cota", self.manual_text))
        edit_layout.addWidget(self.override_stack)
        reason_row = QtWidgets.QFormLayout()
        self.reason = QtWidgets.QLineEdit()
        self.reason.setPlaceholderText("Opcional, mas recomendado para auditoria")
        reason_row.addRow("Motivo da alteração", self.reason)
        edit_layout.addLayout(reason_row)
        selected_layout.addWidget(edit_box)

        actions = QtWidgets.QHBoxLayout()
        self.apply_button = button("Aplicar alteração", self.apply, primary=True)
        self.more_button = QtWidgets.QToolButton()
        self.more_button.setText("Mais ações  ···")
        self.more_button.setMinimumHeight(40)
        self.more_button.setPopupMode(QtWidgets.QToolButton.ToolButtonPopupMode.InstantPopup)
        self.more_menu = QtWidgets.QMenu(self.more_button)
        self.restore_action = self.more_menu.addAction("Restaurar valor medido")
        self.anchors_action = self.more_menu.addAction("Selecionar referências na viewport")
        self.more_button.setMenu(self.more_menu)
        self.restore_action.triggered.connect(self.restore)
        self.anchors_action.triggered.connect(self.select_anchors)
        actions.addWidget(self.apply_button, 1)
        actions.addWidget(self.more_button)
        selected_layout.addLayout(actions)
        self.selection_stack.addWidget(selected)
        root.addWidget(self.selection_stack)

        self.status = message_label()
        self.status.setText("Selecione uma cota e atualize a leitura quando estiver pronto.")
        root.addWidget(self.status)
        root.addStretch(1)
        self.mode.currentIndexChanged.connect(self._update_enabled)
        self._update_enabled()
        self._load(None)

    @staticmethod
    def _field_page(label: str, field: QtWidgets.QWidget) -> QtWidgets.QWidget:
        page = QtWidgets.QWidget()
        layout = QtWidgets.QFormLayout(page)
        layout.setContentsMargins(0, 4, 0, 4)
        layout.addRow(label, field)
        return page

    def set_styles(self, styles: List[StyleSnapshot]) -> None:
        # Applying appearance remains a single-purpose action on Aparência.
        del styles

    def _update_enabled(self) -> None:
        indexes = {"measured": 0, "rounded": 1, "manualNumeric": 2, "manualText": 3}
        mode = str(self.mode.currentData())
        self.override_stack.setCurrentIndex(indexes.get(mode, 0))
        self.reason.setEnabled(mode != "measured")

    def _load(self, audit: Optional[AuditSnapshot]) -> None:
        self._audit = audit
        if audit is None:
            for widget in (self.dimension_id, self.measured, self.displayed, self.delta, self.anchor, self.orphan):
                widget.setText("—")
            self.selection_stack.setCurrentIndex(0)
            return
        self.dimension_id.setText(audit.dimension_id)
        self.measured.setText(audit.measured_text)
        self.displayed.setText(audit.display_text)
        self.delta.setText(audit.delta_text)
        self.anchor.setText(audit.anchor_desc)
        self.orphan.setText("Referência perdida: " + audit.orphan_reason if audit.is_orphan else "Pronta para uso")
        index = self.mode.findData(audit.mode)
        if index >= 0:
            self.mode.setCurrentIndex(index)
        self.selection_stack.setCurrentIndex(1)

    def refresh(self) -> None:
        try:
            audit = self.bridge.selected_audit()
            self._load(audit)
            if audit is None:
                set_message(self.status, "Nenhuma cota Ameno está selecionada. Selecione uma na viewport e tente novamente.", error=True)
            else:
                set_message(self.status, "Seleção carregada. Revise os valores antes de aplicar uma alteração.")
        except BridgeError as exc:
            set_bridge_error(self.status, exc, "Não foi possível ler a seleção.")

    def apply(self) -> None:
        if self._audit is None:
            set_message(self.status, "Carregue uma cota selecionada antes de aplicar alterações.", error=True)
            return
        try:
            self._load(
                self.bridge.edit_selected(
                    str(self.mode.currentData()),
                    self.rounding.value(),
                    self.manual_value.text(),
                    self.manual_text.text(),
                    self.reason.text(),
                )
            )
            set_message(self.status, "Alteração aplicada à cota selecionada.")
        except BridgeError as exc:
            set_bridge_error(self.status, exc, "Não foi possível alterar a cota.")

    def restore(self) -> None:
        try:
            self._load(self.bridge.restore_selected())
            set_message(self.status, "Valor medido restaurado.")
        except BridgeError as exc:
            set_bridge_error(self.status, exc, "Não foi possível restaurar a medida.")

    def select_anchors(self) -> None:
        try:
            self.bridge.select_anchors()
            set_message(self.status, "Referências selecionadas na viewport.")
        except BridgeError as exc:
            set_bridge_error(self.status, exc, "Não foi possível selecionar as referências.")
