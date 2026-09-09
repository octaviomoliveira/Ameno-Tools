"""Application coordinator; no scene work is performed by navigation."""

from __future__ import annotations

from typing import Optional

from .auth import AuthSession, LocalTokenGateway
from .bridge import UiBridge
from .qt_compat import QtWidgets
from .window import AmenoMainWindow


class AmenoApplication:
    def __init__(self) -> None:
        self.bridge = UiBridge()
        self.auth = AuthSession()
        self.gateway = LocalTokenGateway()
        self.window: Optional[AmenoMainWindow] = None
        self._requested_page = "login"

    def show(self, page: str = "login") -> None:
        self._requested_page = page or "login"
        if self.window is None:
            self.window = AmenoMainWindow(self.bridge, self.authenticate, self.logout)
            self.window.closed.connect(self._on_closed)
        self.window.show()
        self.window.raise_()
        self.window.activateWindow()
        if self.auth.authenticated:
            self.window.show_application(self._requested_page if self._requested_page != "login" else "create")
        else:
            self.window.show_login()

    def authenticate(self, token: str) -> None:
        if self.window is None:
            return
        self.window.set_authenticating(True)
        QtWidgets.QApplication.processEvents()
        result = self.auth.authenticate(token, self.gateway)
        self.window.set_authenticating(False)
        if result.success:
            page = self._requested_page if self._requested_page not in ("", "login", "create-continuous") else "create"
            # Trocar para o App antes de tocar na cena. Uma leitura síncrona de
            # refreshSnapshot pode ser pesada ou aguardar o host; ela nunca
            # pode impedir o usuário de sair da tela de Login. Cada página
            # oferece sua própria atualização explícita depois que o shell
            # está visível.
            self.window.show_application(page)
            self.window.shell.pages["create"].status.setText(
                "Sessão aberta. Atualize o estado da cena quando necessário."
            )
        else:
            self.window.report_login(result.message, error=True)

    def logout(self) -> None:
        self.auth.logout()
        if self.window is not None:
            self.window.show_login("Sessão encerrada. Informe o token novamente.")

    def close(self) -> None:
        if self.window is not None:
            self.window.close()

    def is_open(self) -> bool:
        return bool(self.window is not None and self.window.isVisible())

    def _on_closed(self) -> None:
        self.window = None
