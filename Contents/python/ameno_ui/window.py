"""Single native Qt window and fixed page tree."""

from __future__ import annotations

from typing import Callable, Dict, Optional

from .bridge import BridgeError, UiBridge
from .common import button, set_message
from .config_page import ConfigPage
from .create_page import CreatePage
from .edit_page import EditPage
from .login_page import LoginPage
from .models import SceneSnapshot
from .qt_compat import QtCore, QtGui, QtWidgets, max_parent
from .render_page import RenderPage
from .styles_page import StylesPage


class AppShell(QtWidgets.QWidget):
    def __init__(self, bridge: UiBridge, logout: Callable[[], None]) -> None:
        super().__init__()
        self.pages: Dict[str, QtWidgets.QWidget] = {}
        self.page_views: Dict[str, QtWidgets.QScrollArea] = {}
        layout = QtWidgets.QHBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        sidebar = QtWidgets.QFrame()
        sidebar.setObjectName("Sidebar")
        sidebar.setMinimumWidth(170)
        side_layout = QtWidgets.QVBoxLayout(sidebar)
        side_layout.setContentsMargins(14, 18, 14, 14)
        brand = QtWidgets.QLabel("AMENO")
        brand.setObjectName("SidebarBrand")
        side_layout.addWidget(brand)
        side_layout.addSpacing(12)
        self.nav = QtWidgets.QButtonGroup(self)
        self.nav.setExclusive(True)
        content = QtWidgets.QStackedWidget()
        content.setObjectName("ContentStack")
        self.content = content
        for key, label in (("create", "Criar"), ("styles", "Estilos"), ("edit", "Editar"), ("render", "Render"), ("config", "Configuração")):
            page_button = QtWidgets.QPushButton(label)
            page_button.setCheckable(True)
            page_button.setMinimumHeight(36)
            self.nav.addButton(page_button)
            side_layout.addWidget(page_button)
            page_button.clicked.connect(lambda checked=False, name=key: self.show_page(name))
        side_layout.addStretch(1)
        hint = QtWidgets.QLabel("Interface Qt\nMax 2026")
        hint.setObjectName("Muted")
        side_layout.addWidget(hint)
        layout.addWidget(sidebar)

        self.pages["create"] = CreatePage(bridge)
        self.pages["styles"] = StylesPage(bridge)
        self.pages["edit"] = EditPage(bridge)
        self.pages["render"] = RenderPage(bridge)
        self.pages["config"] = ConfigPage(bridge, logout)
        for key in ("create", "styles", "edit", "render", "config"):
            # Cada página recebe um único host de rolagem no construtor. O
            # host nunca é trocado durante a navegação, evitando reparenting e
            # mantendo todos os controles acessíveis em telas menores.
            page_view = QtWidgets.QScrollArea()
            page_view.setWidgetResizable(True)
            page_view.setFrameShape(QtWidgets.QFrame.Shape.NoFrame)
            page_view.setHorizontalScrollBarPolicy(QtCore.Qt.ScrollBarPolicy.ScrollBarAsNeeded)
            page_view.setWidget(self.pages[key])
            self.page_views[key] = page_view
            content.addWidget(page_view)
        layout.addWidget(content, 1)
        # O shell é construído atrás da tela de login. Não consultar a cena
        # antes de o token ser aceito; a primeira leitura acontece no
        # coordenador, depois da autenticação.
        self.show_page("create", refresh=False)

    def show_page(self, name: str, refresh: bool = False) -> None:
        page = self.pages.get(name, self.pages["create"])
        view = self.page_views.get(name, self.page_views["create"])
        self.content.setCurrentWidget(view)
        for button_widget in self.nav.buttons():
            button_widget.setChecked(button_widget.text().lower() == {"create": "criar", "styles": "estilos", "edit": "editar", "render": "render", "config": "configuração"}.get(name))
        if refresh and hasattr(page, "refresh"):
            # Callers use this only after an explicit command/authentication;
            # sidebar navigation itself remains local and never touches Max.
            page.refresh()


class AmenoMainWindow(QtWidgets.QMainWindow):
    closed = QtCore.Signal()

    def __init__(self, bridge: UiBridge, authenticate: Callable[[str], None], logout: Callable[[], None]) -> None:
        parent = max_parent()
        super().__init__(parent)
        self.bridge = bridge
        self.setWindowTitle("Ameno Tools · Cotas")
        self.setObjectName("AmenoMainWindow")
        self.setWindowFlags(QtCore.Qt.WindowType.Window | QtCore.Qt.WindowType.WindowMinimizeButtonHint | QtCore.Qt.WindowType.WindowMaximizeButtonHint | QtCore.Qt.WindowType.WindowCloseButtonHint)
        self.setMinimumSize(780, 560)
        self.resize(980, 720)
        self.setAttribute(QtCore.Qt.WidgetAttribute.WA_DeleteOnClose, True)
        self._authenticate = authenticate
        self._logout_callback = logout
        self.login_page = LoginPage(authenticate)
        self.shell = AppShell(bridge, logout)
        self.stack = QtWidgets.QStackedWidget()
        self.stack.addWidget(self.login_page)
        self.stack.addWidget(self.shell)
        self.setCentralWidget(self.stack)
        self.stack.setCurrentWidget(self.login_page)
        self._restore_geometry()

    def _restore_geometry(self) -> None:
        settings = QtCore.QSettings("Ameno", "AmenoTools")
        geometry = settings.value("window/geometry")
        if geometry is not None:
            try:
                self.restoreGeometry(geometry)
            except Exception:
                pass
        maximized = settings.value("window/maximized", False)
        if isinstance(maximized, str):
            maximized = maximized.strip().lower() in ("1", "true", "yes", "on")
        if bool(maximized):
            self.setWindowState(self.windowState() | QtCore.Qt.WindowState.WindowMaximized)

    def _save_geometry(self) -> None:
        settings = QtCore.QSettings("Ameno", "AmenoTools")
        settings.setValue("window/geometry", self.saveGeometry())
        settings.setValue("window/maximized", self.isMaximized())

    def show_login(self, message: str = "") -> None:
        self.stack.setCurrentWidget(self.login_page)
        if message:
            self.login_page.set_status(message)
        self.login_page.token.setFocus()

    def show_application(self, page: str = "create") -> None:
        self.stack.setCurrentWidget(self.shell)
        self.shell.show_page(page if page in self.shell.pages else "create")

    def set_authenticating(self, busy: bool) -> None:
        self.login_page.set_busy(busy)

    def report_login(self, message: str, error: bool = False) -> None:
        self.login_page.set_status(message, error)

    def closeEvent(self, event) -> None:  # noqa: N802 - Qt API
        # O fechamento cancela uma eventual coleta antes de destruir a única
        # janela; assim nenhum MouseTool fica vivo com referência à UI.
        if self.stack.currentWidget() is self.shell:
            try:
                self.bridge.cancel_interactive()
            except BridgeError:
                pass
        self._save_geometry()
        self.closed.emit()
        event.accept()
