"""Authentication boundary.

The production endpoint contract has not been supplied yet. The local gateway
therefore validates only that a non-empty token was entered, keeps it in memory,
and clearly labels the session as local. No token is serialized or logged.
"""

from __future__ import annotations

from dataclasses import dataclass
from enum import Enum
from typing import Optional


class AuthState(str, Enum):
    LOGGED_OUT = "logged_out"
    VALIDATING = "validating"
    AUTHENTICATED = "authenticated"
    ERROR = "error"


@dataclass(frozen=True)
class AuthResult:
    success: bool
    state: AuthState
    message: str = ""


class AuthGateway:
    def validate(self, token: str) -> AuthResult:
        raise NotImplementedError


class LocalTokenGateway(AuthGateway):
    """Temporary local gate until the server endpoint is defined."""

    def validate(self, token: str) -> AuthResult:
        if token is None or not token.strip():
            return AuthResult(False, AuthState.ERROR, "Informe o token para continuar.")
        return AuthResult(True, AuthState.AUTHENTICATED, "Sessão local autenticada.")


class AuthSession:
    def __init__(self) -> None:
        self.state = AuthState.LOGGED_OUT
        self._token: Optional[str] = None

    @property
    def authenticated(self) -> bool:
        return self.state == AuthState.AUTHENTICATED and bool(self._token)

    def authenticate(self, token: str, gateway: AuthGateway) -> AuthResult:
        self.state = AuthState.VALIDATING
        try:
            result = gateway.validate(token)
        except Exception:
            # Um gateway futuro pode falhar por rede/contrato. Nunca deixe a
            # exceção chegar ao signal Qt nem mantenha o estado VALIDATING.
            self._token = None
            self.state = AuthState.ERROR
            return AuthResult(False, AuthState.ERROR, "Não foi possível validar o token nesta sessão.")
        if result.success:
            self._token = token.strip()
            self.state = AuthState.AUTHENTICATED
        else:
            self._token = None
            self.state = AuthState.ERROR
        return result

    def logout(self) -> None:
        self._token = None
        self.state = AuthState.LOGGED_OUT

    def clear(self) -> None:
        self.logout()
