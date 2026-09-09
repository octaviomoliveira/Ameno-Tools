"""Configuration and account page."""

from __future__ import annotations

from typing import Callable

from .bridge import BridgeError, UiBridge
from .common import button, group, message_label, set_bridge_error, set_message
from .components import Disclosure, PageHeader
from .host_info import collect
from .qt_compat import QtWidgets


class ConfigPage(QtWidgets.QWidget):
    def __init__(self, bridge: UiBridge, logout: Callable[[], None]) -> None:
        super().__init__()
        self.setObjectName("ConfigPage")
        self.bridge = bridge
        self._logout = logout
        root = QtWidgets.QVBoxLayout(self)
        root.setContentsMargins(30, 26, 30, 30)
        root.setSpacing(14)
        root.addWidget(PageHeader("Configuração", "Conta, ambiente e informações para suporte.", "AMENO"))

        account_box = group("Conta")
        account_layout = QtWidgets.QVBoxLayout(account_box)
        self.session = QtWidgets.QLabel("Sessão autenticada")
        self.session.setObjectName("SectionTitle")
        account_layout.addWidget(self.session)
        privacy = QtWidgets.QLabel("O token fica somente em memória e será apagado ao sair.")
        privacy.setObjectName("Muted")
        account_layout.addWidget(privacy)
        self.logout_button = button("Sair da conta", self._logout)
        account_layout.addWidget(self.logout_button, 0)
        root.addWidget(account_box)

        info_box = group("Informações técnicas")
        info = QtWidgets.QFormLayout(info_box)
        host = collect()
        self.version = QtWidgets.QLabel(host["max"])
        self.python = QtWidgets.QLabel(host["python"])
        self.binding = QtWidgets.QLabel("%s / Qt %s" % (host["binding"], host["qt"]))
        info.addRow("Max", self.version)
        info.addRow("Python", self.python)
        info.addRow("Qt", self.binding)
        self.technical = Disclosure("Ver detalhes do ambiente", info_box, expanded=False)
        root.addWidget(self.technical)
        self.copy_button = button("Copiar diagnóstico para suporte", self.copy_diagnostic)
        root.addWidget(self.copy_button)
        self.status = message_label()
        self.status.setText("O diagnóstico não inclui o token da conta.")
        root.addWidget(self.status)
        root.addStretch(1)

    def copy_diagnostic(self) -> None:
        try:
            text = self.bridge.diagnostic()
            QtWidgets.QApplication.clipboard().setText(text)
            set_message(self.status, "Diagnóstico copiado sem token.")
        except BridgeError as exc:
            set_bridge_error(self.status, exc, "Não foi possível gerar o diagnóstico.")
