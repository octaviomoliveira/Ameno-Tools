"""Guided quotation flow with local drafts and explicit scene commands."""

from __future__ import annotations

from typing import Callable, Dict, List, Optional

from .bridge import BridgeError, UiBridge
from .common import button, group, message_label, set_bridge_error, set_message
from .components import ChoiceGroup, Disclosure, PageHeader, SectionHeading, SegmentedChoice, StatusDot
from .models import CreateSnapshot, SceneSnapshot, StyleSnapshot
from .preferences import settings
from .qt_compat import QtCore, QtWidgets


class CreatePage(QtWidgets.QWidget):
    """The main flow: intent first, advanced formatting only on demand."""

    def __init__(self, bridge: UiBridge) -> None:
        super().__init__()
        self.setObjectName("CreatePage")
        self.bridge = bridge
        self._styles: List[StyleSnapshot] = []
        self._pending_action: Optional[str] = None
        self._preferences = settings()

        root = QtWidgets.QVBoxLayout(self)
        root.setContentsMargins(30, 26, 30, 30)
        root.setSpacing(10)
        root.addWidget(
            PageHeader(
                "Cotar",
                "Escolha como medir e inicie a cotação.",
                "COTAR",
            )
        )

        # Help exists on demand, but never competes with the primary flow.
        self.guide = QtWidgets.QFrame()
        self.guide.setObjectName("Card")
        guide_layout = QtWidgets.QVBoxLayout(self.guide)
        guide_layout.setSpacing(4)
        guide_layout.addWidget(SectionHeading("Como começar"))
        guide_text = QtWidgets.QLabel(
            "Escolha a medição e a orientação. Depois, inicie e clique na viewport.\n"
            "Esc cancela · Ctrl+Z desfaz."
        )
        guide_text.setWordWrap(True)
        guide_layout.addWidget(guide_text)
        root.addWidget(self.guide)

        root.addWidget(SectionHeading("Como você quer medir?"))
        self.tool_choice = ChoiceGroup(
            (
                ("Uma medida", "Seleciona uma única cota", "single"),
                ("Várias medidas", "Cria uma sequência contínua", "continuous"),
            )
        )
        self._last_tool_choice = self.tool_choice.value()
        root.addWidget(self.tool_choice)
        root.addWidget(SectionHeading("Orientação do desenho"))
        self.plane_choice = ChoiceGroup(
            (
                ("Planta", "Medições no plano horizontal", "worldXY"),
                ("Fachada / Vista", "Medições alinhadas à vista", "viewPlane"),
            )
        )
        root.addWidget(self.plane_choice)

        root.addWidget(SectionHeading("Direção"))
        self.mode = SegmentedChoice(
            (
                ("Automática", "aligned", "direcao-automatica"),
                ("Horizontal", "horizontal", "direcao-horizontal"),
                ("Vertical", "vertical", "direcao-vertical"),
            )
        )
        root.addWidget(self.mode)
        self.direction_message = QtWidgets.QLabel()
        self.direction_message.setObjectName("DirectionRule")
        self.direction_message.setWordWrap(True)
        self.direction_message.setVisible(False)
        root.addWidget(self.direction_message)

        details_box = group("")
        details_form = QtWidgets.QFormLayout(details_box)
        details_form.setFieldGrowthPolicy(QtWidgets.QFormLayout.FieldGrowthPolicy.AllNonFixedFieldsGrow)
        self.style = QtWidgets.QComboBox()
        self.unit = QtWidgets.QComboBox()
        for label, value in (
            ("Milímetros", "millimeters"),
            ("Centímetros", "centimeters"),
            ("Metros", "meters"),
            ("Polegadas", "inches"),
        ):
            self.unit.addItem(label, value)
        self.precision = QtWidgets.QSpinBox()
        self.precision.setRange(0, 4)
        self.precision.setSuffix(" casas")
        self.follow_line = QtWidgets.QCheckBox("Texto acompanha a linha")
        self.follow_line.setChecked(True)
        details_form.addRow("Aparência", self.style)
        details_form.addRow("Unidade", self.unit)
        details_form.addRow("Precisão", self.precision)
        details_form.addRow("Texto", self.follow_line)
        self.details = Disclosure("Ajustar detalhes", details_box, expanded=False)
        scene_box = QtWidgets.QFrame()
        scene_box.setObjectName("SceneCard")
        self.action_box = scene_box
        action_layout = QtWidgets.QHBoxLayout(scene_box)
        action_layout.setContentsMargins(16, 12, 16, 12)
        action_layout.setSpacing(12)
        self.scene_dot = StatusDot()
        action_layout.addWidget(self.scene_dot, 0, QtCore.Qt.AlignmentFlag.AlignTop)
        state_copy = QtWidgets.QVBoxLayout()
        state_copy.setSpacing(2)
        self.scene_status = QtWidgets.QLabel("Cena não verificada")
        self.scene_status.setObjectName("SceneTitle")
        state_copy.addWidget(self.scene_status)
        self.selection_summary = QtWidgets.QLabel()
        self.selection_summary.setObjectName("SelectionSummary")
        self.selection_summary.setWordWrap(True)
        state_copy.addWidget(self.selection_summary)
        action_layout.addLayout(state_copy, 1)
        action_layout.addWidget(self._vertical_rule())
        scene_meta = QtWidgets.QVBoxLayout()
        scene_meta.setSpacing(2)
        self.scene_detail = QtWidgets.QLabel("")
        self.scene_detail.setObjectName("Muted")
        self.scene_detail.setWordWrap(True)
        self.count_label = QtWidgets.QLabel("0 cota(s)")
        self.count_label.setObjectName("Meta")
        self.count_label.setAlignment(QtCore.Qt.AlignmentFlag.AlignRight)
        self.scene_detail.setAlignment(QtCore.Qt.AlignmentFlag.AlignRight)
        scene_meta.addWidget(self.count_label)
        scene_meta.addWidget(self.scene_detail)
        action_layout.addLayout(scene_meta)
        root.addWidget(scene_box)

        button_row = QtWidgets.QHBoxLayout()
        button_row.setSpacing(10)
        self.start_button = button("Iniciar cotação", self.start_selected, primary=True)
        self.start_button.setAccessibleName("Iniciar cotação")
        self.start_button.setMinimumWidth(260)
        self.more_button = QtWidgets.QToolButton()
        self.more_button.setText("Mais ações")
        self.more_button.setAccessibleName("Mais ações de cotação")
        self.more_button.setMinimumHeight(40)
        self.more_button.setPopupMode(QtWidgets.QToolButton.ToolButtonPopupMode.InstantPopup)
        self.more_menu = QtWidgets.QMenu(self.more_button)
        self.refresh_action = self.more_menu.addAction("Atualizar estado da cena")
        self.prepare_action = self.more_menu.addAction("Preparar cena")
        self.more_menu.addSeparator()
        self.repair_action = self.more_menu.addAction("Reparar todas as cotas")
        self.delete_selection_action = self.more_menu.addAction("Excluir cotas selecionadas…")
        self.clear_orphans_action = self.more_menu.addAction("Limpar cotas órfãs…")
        self.delete_all_action = self.more_menu.addAction("Excluir todas as cotas…")
        self.more_button.setMenu(self.more_menu)
        button_row.addWidget(self.start_button, 1)
        button_row.addWidget(self.more_button)
        root.addLayout(button_row)
        root.addWidget(self.details)

        self.status = message_label()
        self.status.setText("")
        self.status.setVisible(False)
        root.addWidget(self.status)
        root.addStretch(1)

        self.refresh_action.triggered.connect(self.refresh)
        self.prepare_action.triggered.connect(self.prepare_scene)
        self.repair_action.triggered.connect(self.repair_all)
        self.delete_selection_action.triggered.connect(self.delete_selected)
        self.clear_orphans_action.triggered.connect(self.clear_orphan_dimensions)
        self.delete_all_action.triggered.connect(self.delete_all_dimensions)
        for value, choice_button in self.tool_choice.items():
            choice_button.toggled.connect(
                lambda checked=False, item=value: self._on_tool_choice_toggled(item, checked)
            )
        self.mode.changed.connect(self._on_direction_changed)
        self.tool_choice.changed.connect(self._save_preferences)
        self.tool_choice.changed.connect(lambda *_args: self._update_summary())
        self.plane_choice.changed.connect(self._save_preferences)
        self.plane_choice.changed.connect(lambda *_args: self._update_summary())
        self.mode.currentIndexChanged.connect(self._save_preferences)
        self.style.currentIndexChanged.connect(self._save_preferences)
        self.unit.currentIndexChanged.connect(self._save_preferences)
        self.precision.valueChanged.connect(self._save_preferences)
        self.follow_line.toggled.connect(self._save_preferences)
        self.mode.currentIndexChanged.connect(lambda *_args: self._update_summary())
        self.style.currentIndexChanged.connect(lambda *_args: self._update_summary())
        self.unit.currentIndexChanged.connect(lambda *_args: self._update_summary())
        self.precision.valueChanged.connect(lambda *_args: self._update_summary())

        # Compatibility aliases retained for callers from the functional E15
        # surface. They are actions now, not duplicate visible buttons.
        self.individual = self.start_button
        self.continuous = self.start_button
        self.prepare = self.prepare_action
        self.refresh_button = self.refresh_action
        self.repair = self.repair_action
        self.delete_selection = self.delete_selection_action
        self.clear_orphans = self.clear_orphans_action
        self.delete_all = self.delete_all_action
        self._restore_preferences()
        self._last_tool_choice = self.tool_choice.value()
        self._sync_direction_rule(notify=False)
        self._update_summary()
        self.guide.setVisible(False)

    @property
    def pending_action(self) -> Optional[str]:
        return self._pending_action

    @pending_action.setter
    def pending_action(self, value: Optional[str]) -> None:
        self._pending_action = value

    def _setting_bool(self, key: str, default: bool) -> bool:
        value = self._preferences.value(key, default)
        if isinstance(value, str):
            return value.strip().lower() in ("1", "true", "yes", "on")
        return bool(value)

    def show_guide(self) -> None:
        self.guide.setVisible(True)
        self.guide.setFocus()

    def hide_guide(self) -> None:
        self.guide.setVisible(False)
        self._preferences.setValue("onboarding/seen", True)

    def _update_summary(self) -> None:
        tool = "uma medida" if self.tool_choice.value() == "single" else "várias medidas"
        plane = "planta" if self.plane_choice.value() == "worldXY" else "fachada/vista"
        direction = {
            "aligned": "automática",
            "horizontal": "horizontal",
            "vertical": "vertical",
        }.get(str(self.mode.currentData()), "direção")
        unit = str(self.unit.currentText() or "unidade padrão").lower()
        self.selection_summary.setText(
            "%s · %s · %s · %s"
            % (plane, tool, direction, unit)
        )

    def _on_tool_choice_toggled(self, value: str, checked: bool) -> None:
        if not checked:
            return
        changed = value != self._last_tool_choice
        self._last_tool_choice = value
        self._sync_direction_rule(notify=changed)

    def _on_direction_changed(self, _value: str) -> None:
        if self.tool_choice.value() == "continuous":
            self._show_direction_message(
                "Em várias medidas, a direção automática não está disponível.",
                feedback=False,
            )
        else:
            self.direction_message.setVisible(False)

    def _sync_direction_rule(self, notify: bool) -> None:
        continuous = self.tool_choice.value() == "continuous"
        was_automatic = self.mode.currentData() == "aligned"
        if continuous and (was_automatic or notify):
            self.mode.set_value("horizontal", emit=True)
        self.mode.set_item_enabled("aligned", not continuous)
        if continuous:
            message = (
                "Direção alterada para Horizontal · Automática só funciona em uma medida."
                if notify and was_automatic
                else "Em várias medidas, a direção automática não está disponível."
            )
            self._show_direction_message(message, feedback=bool(notify and was_automatic))
        else:
            self.direction_message.setVisible(False)

    def _show_direction_message(self, text: str, feedback: bool) -> None:
        self.direction_message.setText(text)
        self.direction_message.setProperty("feedback", feedback)
        self.direction_message.setVisible(True)

    @staticmethod
    def _vertical_rule() -> QtWidgets.QFrame:
        rule = QtWidgets.QFrame()
        rule.setObjectName("SceneRule")
        rule.setFrameShape(QtWidgets.QFrame.Shape.VLine)
        return rule

    def _restore_preferences(self) -> None:
        self.tool_choice.set_value(str(self._preferences.value("create/tool", "single")))
        self.plane_choice.set_value(str(self._preferences.value("create/plane", "worldXY")))
        self._set_combo(self.mode, str(self._preferences.value("create/mode", "aligned")))
        self._set_combo(self.unit, str(self._preferences.value("create/unit", "meters")))
        try:
            precision = int(self._preferences.value("create/precision", 2))
        except Exception:
            precision = 2
        self.precision.setValue(max(0, min(4, precision)))
        self.follow_line.setChecked(self._setting_bool("create/followLine", True))

    def _save_preferences(self, *_args) -> None:
        self._preferences.setValue("create/tool", self.tool_choice.value())
        self._preferences.setValue("create/plane", self.plane_choice.value())
        self._preferences.setValue("create/mode", str(self.mode.currentData() or "aligned"))
        self._preferences.setValue("create/style", str(self.style.currentData() or "default"))
        self._preferences.setValue("create/unit", str(self.unit.currentData() or "meters"))
        self._preferences.setValue("create/precision", self.precision.value())
        self._preferences.setValue("create/followLine", self.follow_line.isChecked())

    def _set_combo(self, combo, value: str) -> None:
        index = combo.findData(value)
        if index >= 0:
            blocker = QtCore.QSignalBlocker(combo)
            combo.setCurrentIndex(index)
            del blocker

    def load_styles(self, styles: List[StyleSnapshot]) -> None:
        self._styles = list(styles)
        current = self.style.currentData() or self._preferences.value("create/style", "default")
        blocker = QtCore.QSignalBlocker(self.style)
        self.style.clear()
        for item in self._styles:
            self.style.addItem(item.name, item.style_id)
        if self.style.count() == 0:
            self.style.addItem("Arquitetônico", "default")
        del blocker
        self._set_combo(self.style, str(current))

    def load_snapshot(self, snapshot: Dict) -> None:
        scene: SceneSnapshot = snapshot.get("scene", SceneSnapshot())
        create: CreateSnapshot = snapshot.get("create", CreateSnapshot())
        self.scene_status.setText(scene.status_label)
        self.scene_dot.set_ready(scene.status == "ready")
        self.scene_detail.setText(scene.detail)
        self.count_label.setText("%d cota(s)" % scene.dimension_count)
        self.plane_choice.set_value(create.plane)
        self._set_combo(self.mode, create.mode)
        self._set_combo(self.style, create.style_id)
        self._set_combo(self.unit, create.unit)
        blocker = QtCore.QSignalBlocker(self.precision)
        self.precision.setValue(create.precision)
        del blocker
        blocker = QtCore.QSignalBlocker(self.follow_line)
        self.follow_line.setChecked(create.text_follows_line)
        self._sync_direction_rule(notify=False)
        self._update_summary()
        del blocker

    def showEvent(self, event) -> None:  # noqa: N802 - Qt API
        super().showEvent(event)
        self._last_tool_choice = self.tool_choice.value()
        self._sync_direction_rule(notify=False)

    def refresh(self) -> None:
        try:
            snapshot = self.bridge.refresh()
            self.load_styles(snapshot["styles"])
            self.load_snapshot(snapshot)
            set_message(self.status, "Estado da cena atualizado.")
        except BridgeError as exc:
            set_bridge_error(self.status, exc, "Não foi possível atualizar a cena.")

    def apply_settings(self) -> bool:
        """Send exactly one consolidated draft immediately before a tool starts."""
        if self.style.currentData() is None:
            set_message(self.status, "Nenhuma aparência está disponível. Atualize o estado da cena.", error=True)
            return False
        try:
            self.bridge.set_create_settings(
                str(self.mode.currentData()),
                self.plane_choice.value(),
                str(self.style.currentData()),
                str(self.unit.currentData()),
                self.precision.value(),
                self.follow_line.isChecked(),
            )
            self._save_preferences()
            return True
        except BridgeError as exc:
            set_bridge_error(self.status, exc, "Não foi possível aplicar os detalhes da cotação.")
            return False

    def _set_busy(self, busy: bool) -> None:
        for control in (self.start_button, self.more_button, self.tool_choice, self.plane_choice, self.details):
            control.setEnabled(not busy)

    def _run_tool(self, continuous: bool) -> None:
        self._set_busy(True)
        QtWidgets.QApplication.processEvents()
        try:
            result = self.bridge.start_continuous() if continuous else self.bridge.start_individual()
            self.load_snapshot(result)
            set_message(self.status, "Cotação encerrada. Você pode iniciar outra ou continuar trabalhando na cena.")
        except BridgeError as exc:
            set_bridge_error(self.status, exc, "Não foi possível iniciar a cotação.")
        finally:
            self._set_busy(False)

    def start_selected(self) -> None:
        if self.tool_choice.value() == "continuous" and self.mode.currentData() == "aligned":
            QtWidgets.QMessageBox.warning(
                self,
                "Direção automática indisponível",
                "Em várias medidas, escolha Horizontal ou Vertical para continuar.",
            )
            self.mode.set_item_enabled("aligned", False)
            self.mode.set_value("horizontal", emit=True)
            return
        if not self.apply_settings():
            return
        self._run_tool(self.tool_choice.value() == "continuous")

    def start_individual(self) -> None:
        self.tool_choice.set_value("single")
        self._sync_direction_rule(notify=False)
        self.start_selected()

    def start_continuous(self) -> None:
        self.tool_choice.set_value("continuous")
        self.start_selected()

    def prepare_scene(self) -> None:
        try:
            result = self.bridge.prepare_scene()
            self.refresh()
            set_message(self.status, result.get("label") or "Cena preparada.")
        except BridgeError as exc:
            set_bridge_error(self.status, exc, "Não foi possível preparar a cena.")

    def _maintenance(self, action: Callable[[], int], label: str, confirmation: str = "") -> None:
        if confirmation:
            answer = QtWidgets.QMessageBox.question(
                self,
                "Confirmar exclusão",
                confirmation,
                QtWidgets.QMessageBox.StandardButton.Yes | QtWidgets.QMessageBox.StandardButton.No,
            )
            if answer != QtWidgets.QMessageBox.StandardButton.Yes:
                return
        try:
            count = action()
            self.refresh()
            set_message(self.status, "%s: %d cota(s)." % (label, count))
        except BridgeError as exc:
            set_bridge_error(self.status, exc, "Não foi possível executar a manutenção.")

    def repair_all(self) -> None:
        self._maintenance(self.bridge.repair_all, "Reparo concluído")

    def delete_selected(self) -> None:
        self._maintenance(
            self.bridge.delete_selection,
            "Seleção removida",
            "Excluir somente as cotas atualmente selecionadas? Esta ação pode ser desfeita com Ctrl+Z.",
        )

    def clear_orphan_dimensions(self) -> None:
        self._maintenance(
            self.bridge.clear_orphans,
            "Órfãs removidas",
            "Excluir as cotas cujas referências não existem mais? Esta ação pode ser desfeita com Ctrl+Z.",
        )

    def delete_all_dimensions(self) -> None:
        self._maintenance(
            self.bridge.delete_all,
            "Todas removidas",
            "Excluir todas as cotas Ameno desta cena? Esta ação pode ser desfeita com Ctrl+Z.",
        )
