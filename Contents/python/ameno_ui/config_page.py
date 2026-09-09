"""Configuration and account page."""

from __future__ import annotations

from typing import Callable

from .bridge import BridgeError, UiBridge
from .common import button, group, message_label, set_message
from .host_info import collect
from .qt_compat import QtWidgets


class ConfigPage(QtWidgets.QWidget):
    def __init__(self, bridge: UiBridge, logout: Callable[[], None]) -> None:
        super().__init__()
        self.bridge = bridge
        self._logout = logout
        root = QtWidgets.QVBoxLayout(self)
        root.setContentsMargins(22, 18, 22, 22)
        title = QtWidgets.QLabel("Configuração e conta")
        title.setObjectName("PageTitle")
        root.addWidget(title)
        info_box = group("Ambiente")
        info = QtWidgets.QFormLayout(info_box)
        host = collect()
        self.version = QtWidgets.QLabel(host["max"])
        self.python = QtWidgets.QLabel(host["python"])
        self.binding = QtWidgets.QLabel("%s / Qt %s" % (host["binding"], host["qt"]))
        self.session = QtWidgets.QLabel("Autenticada nesta sessão; token somente em memória.")
        info.addRow("Max", self.version)
        info.addRow("Python", self.python)
        info.addRow("Qt", self.binding)
        info.addRow("Sessão", self.session)
        root.addWidget(info_box)
        actions = QtWidgets.QHBoxLayout()
        actions.addWidget(button("Copiar diagnóstico", self.copy_diagnostic))
        actions.addWidget(button("Logout", self._logout))
        root.addLayout(actions)
        self.status = message_label()
        root.addWidget(self.status)
        root.addStretch(1)

    def copy_diagnostic(self) -> None:
        try:
            text = self.bridge.diagnostic()
            QtWidgets.QApplication.clipboard().setText(text)
            set_message(self.status, "Diagnóstico copiado sem token.")
        except BridgeError as exc:
            set_message(self.status, exc.message, error=True)
