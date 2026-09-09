"""Single native Qt window and fixed page tree."""

from __future__ import annotations

from typing import Callable, Dict, Optional

from .bridge import BridgeError, UiBridge
from .assets import icon
from .components import BrandImage
from .config_page import ConfigPage
from .create_page import CreatePage
from .edit_page import EditPage
from .login_page import LoginPage
from .models import SceneSnapshot
from .preferences import settings
from .qt_compat import QtCore, QtGui, QtWidgets, max_parent
from .render_page import RenderPage
from .styles_page import StylesPage
from .theme import apply_to


class AppShell(QtWidgets.QWidget):
    def __init__(self, bridge: UiBridge, logout: Callable[[], None]) -> None:
        super().__init__()
        self.setObjectName("AppShell")
        self.pages: Dict[str, QtWidgets.QWidget] = {}
        self.page_views: Dict[str, QtWidgets.QScrollArea] = {}
        self._nav_by_key: Dict[str, QtWidgets.QPushButton] = {}
        layout = QtWidgets.QHBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        sidebar = QtWidgets.QFrame()
        sidebar.setObjectName("Sidebar")
        sidebar.setFixedWidth(184)
        side_layout = QtWidgets.QVBoxLayout(sidebar)
        side_layout.setContentsMargins(13, 18, 13, 14)
        brand = BrandImage("brand/ameno-symbol-red.png", 34, 34, fallback="O")
        brand.setAccessibleName("Ameno")
        side_layout.addWidget(brand, 0, QtCore.Qt.AlignmentFlag.AlignLeft)
        product = QtWidgets.QLabel("COTAS  /  MAX 2026")
        product.setObjectName("Meta")
        side_layout.addWidget(product)
        side_layout.addSpacing(18)
        self.nav = QtWidgets.QButtonGroup(self)
        self.nav.setExclusive(True)
        content = QtWidgets.QStackedWidget()
        content.setObjectName("ContentStack")
        self.content = content
        for key, label in (("create", "Cotar"), ("styles", "Aparência"), ("edit", "Revisar"), ("render", "Exportar")):
            page_button = QtWidgets.QPushButton(label)
            page_button.setCheckable(True)
            page_button.setMinimumHeight(36)
            page_button.setProperty("nav", True)
            self.nav.addButton(page_button)
            self._nav_by_key[key] = page_button
            side_layout.addWidget(page_button)
            page_button.clicked.connect(lambda checked=False, name=key: self.show_page(name))
        side_layout.addStretch(1)
        help_button = QtWidgets.QPushButton("?  Como começar")
        help_button.setProperty("nav", True)
        help_button.clicked.connect(self.show_help)
        side_layout.addWidget(help_button)
        config_button = QtWidgets.QPushButton("Configuração")
        config_button.setCheckable(True)
        config_button.setMinimumHeight(36)
        config_button.setProperty("nav", True)
        self.nav.addButton(config_button)
        self._nav_by_key["config"] = config_button
        config_button.clicked.connect(lambda checked=False: self.show_page("config"))
        side_layout.addWidget(config_button)
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
        for key, button_widget in self._nav_by_key.items():
            button_widget.setChecked(key == name)
        if refresh and hasattr(page, "refresh"):
            # Callers use this only after an explicit command/authentication;
            # sidebar navigation itself remains local and never touches Max.
            page.refresh()

    def show_help(self) -> None:
        self.show_page("create")
        self.pages["create"].show_guide()


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
        self.setWindowIcon(icon("brand/ameno-symbol-red.png"))
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
        # Keep the host palette untouched: the stylesheet belongs only to
        # this top-level Ameno window and its descendants.
        apply_to(self)
        self._restore_geometry()

    def _restore_geometry(self) -> None:
        preferences = settings()
        geometry = preferences.value("window/geometry")
        if geometry is not None:
            try:
                self.restoreGeometry(geometry)
            except Exception:
                pass
        maximized = preferences.value("window/maximized", False)
        if isinstance(maximized, str):
            maximized = maximized.strip().lower() in ("1", "true", "yes", "on")
        if bool(maximized):
            self.setWindowState(self.windowState() | QtCore.Qt.WindowState.WindowMaximized)

    def _save_geometry(self) -> None:
        preferences = settings()
        preferences.setValue("window/geometry", self.saveGeometry())
        preferences.setValue("window/maximized", self.isMaximized())

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
