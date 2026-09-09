"""Render page; file dialogs and clipboard stay entirely on the Qt side."""

from __future__ import annotations

import os
from typing import Optional

from .bridge import BridgeError, UiBridge
from .common import button, group, message_label, set_message
from .qt_compat import QtCore, QtGui, QtWidgets


class RenderPage(QtWidgets.QWidget):
    def __init__(self, bridge: UiBridge) -> None:
        super().__init__()
        self.bridge = bridge
        root = QtWidgets.QVBoxLayout(self)
        root.setContentsMargins(22, 18, 22, 22)
        title = QtWidgets.QLabel("Renderizar cotas")
        title.setObjectName("PageTitle")
        root.addWidget(title)
        renderer_box = group("Renderer")
        renderer_form = QtWidgets.QFormLayout(renderer_box)
        self.renderer = QtWidgets.QLabel("Atualize o estado para detectar o renderer.")
        self.camera = QtWidgets.QLabel("Vista atual do 3ds Max")
        renderer_form.addRow("Estado", self.renderer)
        renderer_form.addRow("Câmera", self.camera)
        root.addWidget(renderer_box)

        output_box = group("Saída")
        output_form = QtWidgets.QFormLayout(output_box)
        path_row = QtWidgets.QHBoxLayout()
        self.path = QtWidgets.QLineEdit()
        self.browse = button("Escolher…", self.choose_path)
        path_row.addWidget(self.path, 1)
        path_row.addWidget(self.browse)
        path_host = QtWidgets.QWidget()
        path_host.setLayout(path_row)
        self.scope = QtWidgets.QComboBox()
        self.scope.addItem("Todas", "all")
        self.scope.addItem("Selecionadas", "selected")
        self.only_dimensions = QtWidgets.QCheckBox("Somente cotas (fundo transparente)")
        self.only_dimensions.setChecked(True)
        output_form.addRow("Caminho", path_host)
        output_form.addRow("Escopo", self.scope)
        output_form.addRow("Conteúdo", self.only_dimensions)
        root.addWidget(output_box)

        actions = QtWidgets.QHBoxLayout()
        actions.addWidget(button("Atualizar estado", self.refresh))
        actions.addWidget(button("Renderizar", self.render, primary=True))
        actions.addWidget(button("Abrir pasta", self.open_folder))
        actions.addWidget(button("Copiar caminho", self.copy_path))
        root.addLayout(actions)
        self.status = message_label()
        root.addWidget(self.status)
        root.addStretch(1)

    def refresh(self) -> None:
        try:
            scene = self.bridge.scene()
            self.renderer.setText("%s · %s" % (scene.renderer_label, scene.renderer_state))
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
            status, result_path = self.bridge.render(path, str(self.scope.currentData()), self.only_dimensions.isChecked())
            self.path.setText(result_path)
            set_message(self.status, "Render concluído: %s" % (status or result_path))
        except BridgeError as exc:
            set_message(self.status, exc.message, error=True)

    def open_folder(self) -> None:
        path = self.path.text().strip()
        folder = path if os.path.isdir(path) else os.path.dirname(path)
        if folder:
            QtGui.QDesktopServices.openUrl(QtCore.QUrl.fromLocalFile(folder))

    def copy_path(self) -> None:
        QtWidgets.QApplication.clipboard().setText(self.path.text())
        set_message(self.status, "Caminho copiado.")
