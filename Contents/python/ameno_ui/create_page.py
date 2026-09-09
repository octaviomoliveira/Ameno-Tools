"""Stable Create page: local controls plus explicit bridge commands only."""

from __future__ import annotations

from typing import Callable, Dict, List, Optional

from .bridge import BridgeError, UiBridge
from .common import button, group, message_label, scroll, set_message
from .models import CreateSnapshot, SceneSnapshot, StyleSnapshot
from .qt_compat import QtCore, QtWidgets


class CreatePage(QtWidgets.QWidget):
    def __init__(self, bridge: UiBridge) -> None:
        super().__init__()
        self.bridge = bridge
        self._styles: List[StyleSnapshot] = []
        self._pending_action: Optional[str] = None

        root = QtWidgets.QVBoxLayout(self)
        root.setContentsMargins(22, 18, 22, 22)
        title = QtWidgets.QLabel("Criar cotas")
        title.setObjectName("PageTitle")
        root.addWidget(title)
        subtitle = QtWidgets.QLabel("Escolha o plano e o modo. A viewport só é consultada ao executar ou atualizar.")
        subtitle.setObjectName("Muted")
        subtitle.setWordWrap(True)
        root.addWidget(subtitle)

        scene_box = group("Estado da cena")
        scene_form = QtWidgets.QFormLayout(scene_box)
        self.scene_status = QtWidgets.QLabel("Não carregado")
        self.scene_detail = QtWidgets.QLabel()
        self.scene_detail.setWordWrap(True)
        self.count_label = QtWidgets.QLabel("0 cota(s)")
        scene_form.addRow("Estado", self.scene_status)
        scene_form.addRow("Detalhe", self.scene_detail)
        scene_form.addRow("Contagem", self.count_label)
        root.addWidget(scene_box)

        settings_box = group("Parâmetros")
        form = QtWidgets.QFormLayout(settings_box)
        self.plane = QtWidgets.QComboBox()
        self.plane.addItem("Planta (XY)", "worldXY")
        self.plane.addItem("Fachada / Vista", "viewPlane")
        self.mode = QtWidgets.QComboBox()
        self.mode.addItem("Alinhada", "aligned")
        self.mode.addItem("Horizontal", "horizontal")
        self.mode.addItem("Vertical", "vertical")
        self.style = QtWidgets.QComboBox()
        self.unit = QtWidgets.QComboBox()
        for label, value in (("Milímetros", "millimeters"), ("Centímetros", "centimeters"), ("Metros", "meters"), ("Polegadas", "inches")):
            self.unit.addItem(label, value)
        self.precision = QtWidgets.QSpinBox()
        self.precision.setRange(0, 4)
        self.precision.setSuffix(" casas")
        self.follow_line = QtWidgets.QCheckBox("Texto acompanha a linha")
        self.follow_line.setChecked(True)
        form.addRow("Plano", self.plane)
        form.addRow("Modo", self.mode)
        form.addRow("Estilo", self.style)
        form.addRow("Unidade", self.unit)
        form.addRow("Precisão", self.precision)
        form.addRow("Orientação", self.follow_line)
        root.addWidget(settings_box)

        tool_box = group("Ferramentas")
        tool_layout = QtWidgets.QGridLayout(tool_box)
        self.individual = button("Cota individual", self.start_individual, primary=True)
        self.continuous = button("Cota contínua", self.start_continuous, primary=True)
        self.prepare = button("Preparar cena", self.prepare_scene)
        self.refresh_button = button("Atualizar estado", self.refresh)
        tool_layout.addWidget(self.individual, 0, 0)
        tool_layout.addWidget(self.continuous, 0, 1)
        tool_layout.addWidget(self.prepare, 1, 0)
        tool_layout.addWidget(self.refresh_button, 1, 1)
        root.addWidget(tool_box)

        maintenance_box = group("Manutenção")
        maintenance = QtWidgets.QGridLayout(maintenance_box)
        self.repair = button("Reparar tudo", self.repair_all)
        self.delete_selection = button("Deletar seleção", self.delete_selected)
        self.clear_orphans = button("Limpar órfãs", self.clear_orphan_dimensions)
        self.delete_all = button("Deletar todas", self.delete_all_dimensions)
        maintenance.addWidget(self.repair, 0, 0)
        maintenance.addWidget(self.delete_selection, 0, 1)
        maintenance.addWidget(self.clear_orphans, 1, 0)
        maintenance.addWidget(self.delete_all, 1, 1)
        root.addWidget(maintenance_box)

        self.status = message_label()
        root.addWidget(self.status)
        root.addStretch(1)

        self.plane.currentIndexChanged.connect(self.apply_settings)
        self.mode.currentIndexChanged.connect(self.apply_settings)
        self.style.currentIndexChanged.connect(self.apply_settings)
        self.unit.currentIndexChanged.connect(self.apply_settings)
        self.precision.valueChanged.connect(self.apply_settings)
        self.follow_line.toggled.connect(self.apply_settings)

    @property
    def pending_action(self) -> Optional[str]:
        return self._pending_action

    @pending_action.setter
    def pending_action(self, value: Optional[str]) -> None:
        self._pending_action = value

    def _set_combo(self, combo: QtWidgets.QComboBox, value: str) -> None:
        index = combo.findData(value)
        if index >= 0:
            blocker = QtCore.QSignalBlocker(combo)
            combo.setCurrentIndex(index)
            del blocker

    def load_styles(self, styles: List[StyleSnapshot]) -> None:
        self._styles = list(styles)
        current = self.style.currentData()
        blocker = QtCore.QSignalBlocker(self.style)
        self.style.clear()
        for item in self._styles:
            self.style.addItem(item.name, item.style_id)
        del blocker
        if current:
            self._set_combo(self.style, str(current))
        if self.style.count() == 0:
            self.style.addItem("Arquitetônico", "default")

    def load_snapshot(self, snapshot: Dict) -> None:
        scene: SceneSnapshot = snapshot.get("scene", SceneSnapshot())
        create: CreateSnapshot = snapshot.get("create", CreateSnapshot())
        self.scene_status.setText(scene.status_label)
        self.scene_detail.setText(scene.detail)
        self.count_label.setText("%d cota(s) ativa(s)" % scene.dimension_count)
        self._set_combo(self.plane, create.plane)
        self._set_combo(self.mode, create.mode)
        self._set_combo(self.style, create.style_id)
        self._set_combo(self.unit, create.unit)
        blocker = QtCore.QSignalBlocker(self.precision)
        self.precision.setValue(create.precision)
        del blocker
        blocker = QtCore.QSignalBlocker(self.follow_line)
        self.follow_line.setChecked(create.text_follows_line)
        del blocker

    def refresh(self) -> None:
        try:
            snapshot = self.bridge.refresh()
            self.load_styles(snapshot["styles"])
            self.load_snapshot(snapshot)
            set_message(self.status, "Estado atualizado.")
        except BridgeError as exc:
            set_message(self.status, exc.message, error=True)

    def apply_settings(self) -> None:
        if not self.isVisible() or self.style.currentData() is None:
            return
        try:
            self.bridge.set_create_settings(str(self.mode.currentData()), str(self.plane.currentData()), str(self.style.currentData()), str(self.unit.currentData()), self.precision.value(), self.follow_line.isChecked())
        except BridgeError as exc:
            set_message(self.status, exc.message, error=True)

    def _run_tool(self, continuous: bool) -> None:
        controls = [self.individual, self.continuous, self.prepare, self.refresh_button, self.repair, self.delete_selection, self.clear_orphans, self.delete_all]
        for control in controls:
            control.setEnabled(False)
        QtWidgets.QApplication.processEvents()
        try:
            result = self.bridge.start_continuous() if continuous else self.bridge.start_individual()
            self.load_snapshot(result)
            set_message(self.status, "Ferramenta encerrada; estado atualizado.")
        except BridgeError as exc:
            set_message(self.status, exc.message, error=True)
        finally:
            for control in controls:
                control.setEnabled(True)

    def start_individual(self) -> None:
        self.apply_settings()
        self._run_tool(False)

    def start_continuous(self) -> None:
        self.apply_settings()
        self._run_tool(True)

    def prepare_scene(self) -> None:
        try:
            result = self.bridge.prepare_scene()
            self.refresh()
            set_message(self.status, result.get("label") or "Cena preparada.")
        except BridgeError as exc:
            set_message(self.status, exc.message, error=True)

    def _maintenance(self, action: Callable[[], int], label: str, confirm: bool = False) -> None:
        if confirm:
            answer = QtWidgets.QMessageBox.question(self, "Confirmar", "Esta ação remove cotas da cena. Continuar?", QtWidgets.QMessageBox.StandardButton.Yes | QtWidgets.QMessageBox.StandardButton.No)
            if answer != QtWidgets.QMessageBox.StandardButton.Yes:
                return
        try:
            count = action()
            self.refresh()
            set_message(self.status, "%s: %d cota(s)." % (label, count))
        except BridgeError as exc:
            set_message(self.status, exc.message, error=True)

    def repair_all(self) -> None:
        self._maintenance(self.bridge.repair_all, "Reparo concluído")

    def delete_selected(self) -> None:
        self._maintenance(self.bridge.delete_selection, "Seleção removida", True)

    def clear_orphan_dimensions(self) -> None:
        self._maintenance(self.bridge.clear_orphans, "Órfãs removidas", True)

    def delete_all_dimensions(self) -> None:
        self._maintenance(self.bridge.delete_all, "Todas removidas", True)
