"""First screen of every Ameno session."""

from __future__ import annotations

from typing import Callable

from .common import button, group, message_label, set_message
from .qt_compat import QtCore, QtWidgets


class LoginPage(QtWidgets.QWidget):
    login_requested = QtCore.Signal(str)

    def __init__(self, submit: Callable[[str], None]) -> None:
        super().__init__()
        self._submit = submit
        root = QtWidgets.QVBoxLayout(self)
        root.setContentsMargins(50, 38, 50, 38)
        root.addStretch(1)
        title = QtWidgets.QLabel("Ameno Tools")
        title.setObjectName("Brand")
        title.setAlignment(QtCore.Qt.AlignmentFlag.AlignCenter)
        root.addWidget(title)
        subtitle = QtWidgets.QLabel("Entre com seu token para abrir as ferramentas de cotação.")
        subtitle.setAlignment(QtCore.Qt.AlignmentFlag.AlignCenter)
        subtitle.setWordWrap(True)
        root.addWidget(subtitle)
        box = group("Login")
        form = QtWidgets.QFormLayout(box)
        self.token = QtWidgets.QLineEdit()
        self.token.setPlaceholderText("Cole o token aqui")
        self.token.setEchoMode(QtWidgets.QLineEdit.EchoMode.Password)
        self.token.setClearButtonEnabled(True)
        self.show_token = QtWidgets.QCheckBox("Mostrar token")
        self.enter = button("Entrar", self.submit, primary=True)
        self.enter.setDefault(True)
        self.cancel = button("Limpar", self.clear)
        self.status = message_label()
        form.addRow("Token", self.token)
        form.addRow("", self.show_token)
        form.addRow("", self.enter)
        form.addRow("", self.cancel)
        form.addRow("", self.status)
        root.addWidget(box)
        root.addStretch(2)
        self.token.textChanged.connect(self._update_enabled)
        self.show_token.toggled.connect(self._toggle_echo)
        self.token.returnPressed.connect(self.submit)
        self._update_enabled()

    def _toggle_echo(self, visible: bool) -> None:
        self.token.setEchoMode(QtWidgets.QLineEdit.EchoMode.Normal if visible else QtWidgets.QLineEdit.EchoMode.Password)

    def _update_enabled(self) -> None:
        self.enter.setEnabled(bool(self.token.text().strip()))

    def submit(self) -> None:
        value = self.token.text().strip()
        if value:
            self._submit(value)

    def set_busy(self, busy: bool) -> None:
        self.token.setEnabled(not busy)
        self.enter.setEnabled(not busy and bool(self.token.text().strip()))
        self.cancel.setEnabled(not busy)

    def set_status(self, text: str, error: bool = False) -> None:
        set_message(self.status, text, error)

    def clear(self) -> None:
        self.token.clear()
        self.set_status("")
        self.token.setFocus()
