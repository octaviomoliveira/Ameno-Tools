"""Branded first screen of every Ameno session."""

from __future__ import annotations

from typing import Callable

from .common import button, message_label, set_message
from .components import BrandImage
from .qt_compat import QtCore, QtWidgets


class LoginPage(QtWidgets.QWidget):
    login_requested = QtCore.Signal(str)

    def __init__(self, submit: Callable[[str], None]) -> None:
        super().__init__()
        self.setObjectName("LoginPage")
        self._submit = submit
        root = QtWidgets.QVBoxLayout(self)
        root.setContentsMargins(38, 34, 38, 38)
        root.addStretch(1)

        brand = BrandImage("brand/ameno-wordmark-dark.png", 310, 70)
        brand.setAlignment(QtCore.Qt.AlignmentFlag.AlignCenter)
        brand.setAccessibleName("Ameno")
        root.addWidget(brand, 0, QtCore.Qt.AlignmentFlag.AlignHCenter)
        product = QtWidgets.QLabel("AMENO COTAS  /  MAX 2026")
        product.setObjectName("Eyebrow")
        product.setAlignment(QtCore.Qt.AlignmentFlag.AlignCenter)
        root.addWidget(product)
        root.addSpacing(24)

        card = QtWidgets.QFrame()
        card.setObjectName("Card")
        card.setMaximumWidth(510)
        form = QtWidgets.QVBoxLayout(card)
        form.setContentsMargins(28, 25, 28, 25)
        form.setSpacing(12)
        title = QtWidgets.QLabel("Entrar no Ameno")
        title.setObjectName("SectionTitle")
        form.addWidget(title)
        subtitle = QtWidgets.QLabel("Cole o token da sua conta para abrir as ferramentas de cotação.")
        subtitle.setObjectName("SectionHint")
        subtitle.setWordWrap(True)
        form.addWidget(subtitle)
        form.addSpacing(5)

        token_label = QtWidgets.QLabel("Token")
        token_label.setObjectName("Meta")
        token_label.setAccessibleName("Token da conta")
        form.addWidget(token_label)
        self.token = QtWidgets.QLineEdit()
        self.token.setPlaceholderText("Cole o token aqui")
        self.token.setAccessibleName("Token da conta Ameno")
        self.token.setEchoMode(QtWidgets.QLineEdit.EchoMode.Password)
        self.token.setClearButtonEnabled(True)
        self.token.setMinimumHeight(38)
        form.addWidget(self.token)
        self.show_token = QtWidgets.QCheckBox("Mostrar token")
        self.show_token.setAccessibleName("Mostrar ou ocultar token")
        form.addWidget(self.show_token)
        self.enter = button("Entrar", self.submit, primary=True)
        self.enter.setAccessibleName("Entrar no Ameno")
        self.enter.setDefault(True)
        form.addWidget(self.enter)
        self.cancel = button("Limpar campo", self.clear)
        self.cancel.setAccessibleName("Limpar token")
        self.cancel.setProperty("quiet", True)
        form.addWidget(self.cancel)
        self.status = message_label()
        self.status.setVisible(False)
        form.addWidget(self.status)
        root.addWidget(card, 0, QtCore.Qt.AlignmentFlag.AlignHCenter)

        privacy = QtWidgets.QLabel("Seu token fica somente nesta sessão e não é salvo no computador.")
        privacy.setObjectName("Muted")
        privacy.setAlignment(QtCore.Qt.AlignmentFlag.AlignCenter)
        privacy.setWordWrap(True)
        root.addSpacing(12)
        root.addWidget(privacy)
        root.addStretch(2)

        self.token.textChanged.connect(self._update_enabled)
        self.show_token.toggled.connect(self._toggle_echo)
        self.token.returnPressed.connect(self.submit)
        self._update_enabled()

    def _toggle_echo(self, visible: bool) -> None:
        self.token.setEchoMode(
            QtWidgets.QLineEdit.EchoMode.Normal if visible else QtWidgets.QLineEdit.EchoMode.Password
        )

    def _update_enabled(self) -> None:
        self.enter.setEnabled(bool(self.token.text().strip()))

    def submit(self) -> None:
        value = self.token.text().strip()
        if value:
            self._submit(value)

    def set_busy(self, busy: bool) -> None:
        self.token.setEnabled(not busy)
        self.enter.setText("Validando…" if busy else "Entrar")
        self.enter.setEnabled(not busy and bool(self.token.text().strip()))
        self.cancel.setEnabled(not busy)

    def set_status(self, text: str, error: bool = False) -> None:
        set_message(self.status, text, error)
        self.status.setVisible(bool(text))

    def clear(self) -> None:
        self.token.clear()
        self.set_status("")
        self.token.setFocus()
