"""Application coordinator; no scene work is performed by navigation."""

from __future__ import annotations

from typing import Optional

from .auth import AuthSession, LocalTokenGateway
from .bridge import BridgeError, UiBridge
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
            self.window.report_login(result.message)
            try:
                snapshot = self.bridge.refresh()
                self.window.shell.pages["create"].load_styles(snapshot["styles"])
                self.window.shell.pages["create"].load_snapshot(snapshot)
            except BridgeError as exc:
                self.window.report_login("Sessão aberta; atualização pendente: %s" % exc.message, error=False)
            page = self._requested_page if self._requested_page not in ("", "login", "create-continuous") else "create"
            self.window.show_application(page)
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
