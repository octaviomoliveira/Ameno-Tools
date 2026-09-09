"""Selection editor using one explicit audit snapshot per refresh."""

from __future__ import annotations

from typing import List, Optional

from .bridge import BridgeError, UiBridge
from .common import button, group, message_label, set_message
from .models import AuditSnapshot, StyleSnapshot
from .qt_compat import QtWidgets


class EditPage(QtWidgets.QWidget):
    def __init__(self, bridge: UiBridge) -> None:
        super().__init__()
        self.bridge = bridge
        self._audit: Optional[AuditSnapshot] = None
        root = QtWidgets.QVBoxLayout(self)
        root.setContentsMargins(22, 18, 22, 22)
        title = QtWidgets.QLabel("Editar cota selecionada")
        title.setObjectName("PageTitle")
        root.addWidget(title)
        root.addWidget(QtWidgets.QLabel("A leitura da seleção acontece somente ao atualizar ou após um comando."))

        info_box = group("Leitura")
        info = QtWidgets.QFormLayout(info_box)
        self.dimension_id = QtWidgets.QLabel("—")
        self.measured = QtWidgets.QLabel("—")
        self.displayed = QtWidgets.QLabel("—")
        self.delta = QtWidgets.QLabel("—")
        self.anchor = QtWidgets.QLabel("—")
        self.orphan = QtWidgets.QLabel("—")
        for label, widget in (("ID", self.dimension_id), ("Medido", self.measured), ("Exibido", self.displayed), ("Delta", self.delta), ("Âncoras", self.anchor), ("Estado", self.orphan)):
            info.addRow(label, widget)
        root.addWidget(info_box)

        edit_box = group("Sobrescrita")
        form = QtWidgets.QFormLayout(edit_box)
        self.mode = QtWidgets.QComboBox()
        for label, value in (("Medido", "measured"), ("Arredondado", "rounded"), ("Numérico", "manualNumeric"), ("Texto", "manualText")):
            self.mode.addItem(label, value)
        self.rounding = QtWidgets.QDoubleSpinBox()
        self.rounding.setRange(0, 1000000)
        self.rounding.setDecimals(2)
        self.rounding.setSuffix(" mm")
        self.manual_value = QtWidgets.QLineEdit()
        self.manual_text = QtWidgets.QLineEdit()
        self.reason = QtWidgets.QLineEdit()
        form.addRow("Modo", self.mode)
        form.addRow("Passo", self.rounding)
        form.addRow("Valor", self.manual_value)
        form.addRow("Texto", self.manual_text)
        form.addRow("Motivo", self.reason)
        root.addWidget(edit_box)

        actions = QtWidgets.QHBoxLayout()
        actions.addWidget(button("Atualizar seleção", self.refresh))
        actions.addWidget(button("Aplicar alteração", self.apply, primary=True))
        actions.addWidget(button("Restaurar medido", self.restore))
        actions.addWidget(button("Selecionar âncoras", self.select_anchors))
        root.addLayout(actions)

        self.status = message_label()
        root.addWidget(self.status)
        root.addStretch(1)
        self.mode.currentIndexChanged.connect(self._update_enabled)
        self._update_enabled()

    def set_styles(self, styles: List[StyleSnapshot]) -> None:
        # The style selector is deliberately omitted until a selected-style
        # combo is needed; applying a style remains available on the Styles page.
        del styles

    def _update_enabled(self) -> None:
        mode = str(self.mode.currentData())
        self.rounding.setEnabled(mode == "rounded")
        self.manual_value.setEnabled(mode == "manualNumeric")
        self.manual_text.setEnabled(mode == "manualText")

    def _load(self, audit: Optional[AuditSnapshot]) -> None:
        self._audit = audit
        if audit is None:
            for widget in (self.dimension_id, self.measured, self.displayed, self.delta, self.anchor, self.orphan):
                widget.setText("Nenhuma cota selecionada")
            return
        self.dimension_id.setText(audit.dimension_id)
        self.measured.setText(audit.measured_text)
        self.displayed.setText(audit.display_text)
        self.delta.setText(audit.delta_text)
        self.anchor.setText(audit.anchor_desc)
        self.orphan.setText("Órfã: " + audit.orphan_reason if audit.is_orphan else "Pronta")
        index = self.mode.findData(audit.mode)
        if index >= 0:
            self.mode.setCurrentIndex(index)

    def refresh(self) -> None:
        try:
            self._load(self.bridge.selected_audit())
            set_message(self.status, "Seleção atualizada.")
        except BridgeError as exc:
            set_message(self.status, exc.message, error=True)

    def apply(self) -> None:
        try:
            self._load(self.bridge.edit_selected(str(self.mode.currentData()), self.rounding.value(), self.manual_value.text(), self.manual_text.text(), self.reason.text()))
            set_message(self.status, "Alteração aplicada.")
        except BridgeError as exc:
            set_message(self.status, exc.message, error=True)

    def restore(self) -> None:
        try:
            self._load(self.bridge.restore_selected())
            set_message(self.status, "Valor medido restaurado.")
        except BridgeError as exc:
            set_message(self.status, exc.message, error=True)

    def select_anchors(self) -> None:
        try:
            self.bridge.select_anchors()
            set_message(self.status, "Âncoras selecionadas no viewport.")
        except BridgeError as exc:
            set_message(self.status, exc.message, error=True)
