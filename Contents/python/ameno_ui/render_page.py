"""Render page; file dialogs and clipboard stay entirely on the Qt side."""

from __future__ import annotations

import os
from typing import Optional

from .bridge import BridgeError, UiBridge
from .common import button, group, message_label, set_message
from .components import PageHeader, StatusPill
from .qt_compat import QtCore, QtGui, QtWidgets


class RenderPage(QtWidgets.QWidget):
    def __init__(self, bridge: UiBridge) -> None:
        super().__init__()
        self.setObjectName("RenderPage")
        self.bridge = bridge
        root = QtWidgets.QVBoxLayout(self)
        root.setContentsMargins(30, 26, 30, 30)
        root.setSpacing(14)
        root.addWidget(
            PageHeader(
                "Exportar",
                "Gere um PNG das cotas para composição, revisão ou entrega.",
                "SAÍDA",
            )
        )
        renderer_box = group("Pronto para exportar")
        renderer_form = QtWidgets.QFormLayout(renderer_box)
        self.renderer = QtWidgets.QLabel("Atualize o estado para detectar o renderer.")
        self.renderer_state = StatusPill("Não verificado")
        self.camera = QtWidgets.QLabel("Vista atual do 3ds Max")
        renderer_form.addRow("Renderer", self.renderer)
        renderer_form.addRow("Estado", self.renderer_state)
        renderer_form.addRow("Origem", self.camera)
        root.addWidget(renderer_box)

        output_box = group("Arquivo")
        output_form = QtWidgets.QFormLayout(output_box)
        path_row = QtWidgets.QHBoxLayout()
        self.path = QtWidgets.QLineEdit()
        self.browse = button("Escolher arquivo…", self.choose_path)
        path_row.addWidget(self.path, 1)
        path_row.addWidget(self.browse)
        path_host = QtWidgets.QWidget()
        path_host.setObjectName("TransparentHost")
        path_host.setLayout(path_row)
        self.scope = QtWidgets.QComboBox()
        self.scope.addItem("Todas as cotas", "all")
        self.scope.addItem("Somente as selecionadas", "selected")
        self.only_dimensions = QtWidgets.QCheckBox("Exportar somente as cotas, com fundo transparente")
        self.only_dimensions.setChecked(True)
        output_form.addRow("Salvar em", path_host)
        output_form.addRow("Incluir", self.scope)
        output_form.addRow("Fundo", self.only_dimensions)
        root.addWidget(output_box)

        actions = QtWidgets.QHBoxLayout()
        self.render_button = button("Exportar PNG", self.render, primary=True)
        self.more_button = QtWidgets.QToolButton()
        self.more_button.setText("Mais ações  ···")
        self.more_button.setMinimumHeight(40)
        self.more_button.setPopupMode(QtWidgets.QToolButton.ToolButtonPopupMode.InstantPopup)
        self.more_menu = QtWidgets.QMenu(self.more_button)
        self.refresh_action = self.more_menu.addAction("Atualizar renderer e caminho")
        self.open_action = self.more_menu.addAction("Abrir pasta de saída")
        self.copy_action = self.more_menu.addAction("Copiar caminho")
        self.more_button.setMenu(self.more_menu)
        self.refresh_action.triggered.connect(self.refresh)
        self.open_action.triggered.connect(self.open_folder)
        self.copy_action.triggered.connect(self.copy_path)
        actions.addWidget(self.render_button, 1)
        actions.addWidget(self.more_button)
        root.addLayout(actions)
        self.status = message_label()
        self.status.setText("Escolha o arquivo. O renderer será consultado apenas ao atualizar ou exportar.")
        root.addWidget(self.status)
        root.addStretch(1)

    def refresh(self) -> None:
        try:
            scene = self.bridge.scene()
            self.renderer.setText("%s · %s" % (scene.renderer_label, scene.renderer_state))
            self.renderer_state.setText(scene.renderer_state or "Não informado")
            if not self.path.text().strip():
                self.path.setText(self.bridge.default_render_path())
            set_message(self.status, "Renderer e caminho atualizados.")
        except BridgeError as exc:
            set_message(self.status, exc.message, error=True)

    def choose_path(self) -> None:
        path, _ = QtWidgets.QFileDialog.getSaveFileName(self, "Salvar render", self.path.text(), "PNG (*.png)")
        if path:
            self.path.setText(path)

    def render(self) -> None:
        path = self.path.text().strip()
        if not path:
            self.refresh()
            path = self.path.text().strip()
        if not path:
            set_message(self.status, "Escolha um caminho de saída.", error=True)
            return
        try:
            self.render_button.setEnabled(False)
            self.render_button.setText("Exportando…")
            QtWidgets.QApplication.processEvents()
            status, result_path = self.bridge.render(path, str(self.scope.currentData()), self.only_dimensions.isChecked())
            self.path.setText(result_path)
            set_message(self.status, "PNG exportado: %s" % (status or result_path))
        except BridgeError as exc:
            set_message(self.status, exc.message, error=True)
        finally:
            self.render_button.setText("Exportar PNG")
            self.render_button.setEnabled(True)

    def open_folder(self) -> None:
        path = self.path.text().strip()
        folder = path if os.path.isdir(path) else os.path.dirname(path)
        if folder:
            QtGui.QDesktopServices.openUrl(QtCore.QUrl.fromLocalFile(folder))

    def copy_path(self) -> None:
        QtWidgets.QApplication.clipboard().setText(self.path.text())
        set_message(self.status, "Caminho copiado.")
