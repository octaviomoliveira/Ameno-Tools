"""Single native Qt window and fixed page tree."""

from __future__ import annotations

from typing import Callable, Dict, Optional

from .bridge import BridgeError, UiBridge
from .assets import icon, nav_icon
from .components import BrandImage
from .config_page import ConfigPage
from .create_page import CreatePage
from .edit_page import EditPage
from .login_page import LoginPage
from .models import SceneSnapshot
from .preferences import settings
from .page_scaffold import apply_page_margins
from .qt_compat import QtCore, QtGui, QtWidgets, max_parent
from .render_page import RenderPage
from .responsive import spec_for_width
from .styles_page import StylesPage
from .theme import apply_to
from .window_geometry import (
    initial_window_geometry,
    recover_window_geometry,
    remap_window_geometry,
    visible_enough,
)


class FixedPageHost(QtWidgets.QScrollArea):
    """Non-scrolling host for pages that own their internal scroll regions."""

    def setWidget(self, widget) -> None:  # noqa: N802 - Qt API
        super().setWidget(widget)
        widget.resize(self.viewport().size())

    def resizeEvent(self, event) -> None:  # noqa: N802 - Qt API
        super().resizeEvent(event)
        child = self.widget()
        if child is not None:
            child.resize(self.viewport().size())


class AppShell(QtWidgets.QWidget):
    def __init__(self, bridge: UiBridge, logout: Callable[[], None]) -> None:
        super().__init__()
        self.setObjectName("AppShell")
        self._responsive_mode = ""
        self._nav_labels = {
            "create": "Cotar",
            "styles": "Estilo",
            "edit": "Revisar",
            "render": "Exportar",
            "config": "Configurações",
        }
        self._nav_icons = {
            "create": "cotar",
            "styles": "aparencia",
            "edit": "revisar",
            "render": "exportar",
            "config": "configuracao",
        }
        self.pages: Dict[str, QtWidgets.QWidget] = {}
        self.page_views: Dict[str, QtWidgets.QScrollArea] = {}
        self._nav_by_key: Dict[str, QtWidgets.QPushButton] = {}
        layout = QtWidgets.QHBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        sidebar = QtWidgets.QFrame()
        sidebar.setObjectName("Sidebar")
        self.sidebar = sidebar
        sidebar.setSizePolicy(QtWidgets.QSizePolicy.Policy.Fixed, QtWidgets.QSizePolicy.Policy.Expanding)
        side_layout = QtWidgets.QVBoxLayout(sidebar)
        side_layout.setContentsMargins(13, 18, 13, 14)
        brand = BrandImage("brand/ameno-symbol-red.png", 34, 34, fallback="O")
        brand.setAccessibleName("Ameno")
        side_layout.addWidget(brand, 0, QtCore.Qt.AlignmentFlag.AlignLeft)
        product = QtWidgets.QLabel("COTAS  /  MAX 2026")
        self.product_meta = product
        product.setObjectName("Meta")
        side_layout.addWidget(product)
        side_layout.addSpacing(18)
        self.nav = QtWidgets.QButtonGroup(self)
        self.nav.setExclusive(True)
        content = QtWidgets.QStackedWidget()
        content.setObjectName("ContentStack")
        self.content = content
        for key, label in (("create", "Cotar"), ("styles", "Estilo"), ("edit", "Revisar"), ("render", "Exportar")):
            page_button = QtWidgets.QPushButton(label)
            page_button.setCheckable(True)
            page_button.setMinimumHeight(36)
            page_button.setProperty("nav", True)
            page_button.setAccessibleName(label)
            page_button.setToolTip(label)
            page_button.setIcon(nav_icon(self._nav_icons[key]))
            self.nav.addButton(page_button)
            self._nav_by_key[key] = page_button
            side_layout.addWidget(page_button)
            page_button.clicked.connect(lambda checked=False, name=key: self.show_page(name))
        side_layout.addStretch(1)
        help_button = QtWidgets.QPushButton("Ajuda")
        self.help_button = help_button
        help_button.setProperty("nav", True)
        help_button.setAccessibleName("Ajuda")
        help_button.setToolTip("Como começar")
        help_button.setIcon(nav_icon("ajuda"))
        help_button.clicked.connect(self.show_help)
        side_layout.addWidget(help_button)
        config_button = QtWidgets.QPushButton("Configurações")
        config_button.setCheckable(True)
        config_button.setMinimumHeight(36)
        config_button.setProperty("nav", True)
        config_button.setAccessibleName("Configurações")
        config_button.setToolTip("Configurações")
        config_button.setIcon(nav_icon(self._nav_icons["config"]))
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
            page_view = FixedPageHost() if key == "styles" else QtWidgets.QScrollArea()
            # Estilo owns its only vertical scroll region. Let FixedPageHost
            # size that page explicitly to the viewport; QScrollArea's normal
            # content-driven sizing would otherwise push the fixed footer out
            # of view at compact heights.
            page_view.setWidgetResizable(key != "styles")
            page_view.setFrameShape(QtWidgets.QFrame.Shape.NoFrame)
            page_view.setHorizontalScrollBarPolicy(QtCore.Qt.ScrollBarPolicy.ScrollBarAsNeeded)
            if key == "styles":
                page_view.setVerticalScrollBarPolicy(QtCore.Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
                page_view.setHorizontalScrollBarPolicy(QtCore.Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
            page_view.setWidget(self.pages[key])
            self.page_views[key] = page_view
            content.addWidget(page_view)
        layout.addWidget(content, 1)
        # O shell é construído atrás da tela de login. Não consultar a cena
        # antes de o token ser aceito; a primeira leitura acontece no
        # coordenador, depois da autenticação.
        self.show_page("create", refresh=False)
        self._apply_responsive_layout()

    def resizeEvent(self, event) -> None:  # noqa: N802 - Qt API
        super().resizeEvent(event)
        self._apply_responsive_layout()

    def _apply_responsive_layout(self) -> None:
        spec = spec_for_width(self.width())
        mode, sidebar_width = spec.mode, spec.sidebar_width
        if mode == self._responsive_mode and self.sidebar.width() == sidebar_width:
            return
        self._responsive_mode = mode
        self.sidebar.setFixedWidth(sidebar_width)
        compact = mode == "compact"
        self.product_meta.setVisible(not compact)
        self.sidebar.layout().setContentsMargins(8 if compact else 13, 18, 8 if compact else 13, 14)
        for key, page in self.pages.items():
            apply_page_margins(page, spec)
            if key == "styles":
                # Estilo owns its only vertical scroll inside the controls
                # column. The page itself must fill, not outgrow, the outer
                # viewport so preview and footer remain fixed.
                page.setMinimumHeight(0)
                page.setSizePolicy(
                    QtWidgets.QSizePolicy.Policy.Ignored,
                    QtWidgets.QSizePolicy.Policy.Ignored,
                )
        for key, widget in self._nav_by_key.items():
            widget.setText("" if compact else self._nav_labels[key])
            widget.setToolTip(self._nav_labels[key])
            widget.setMinimumHeight(40 if compact else 36)
            widget.setIconSize(QtCore.QSize(22 if compact else 18, 22 if compact else 18))
            widget.setProperty("compact", compact)
        # Re-evaluate the dynamic compact selector once per breakpoint. Calling
        # ``widget.style().unpolish/polish`` is unsafe in 3ds Max's embedded
        # Qt: the transient QStyle wrapper can already be deleted while the
        # shell is being constructed. Reapplying the window-scoped stylesheet
        # keeps the same widget tree and avoids that dangling wrapper.
        owner = self.window()
        if owner is not None and owner.styleSheet():
            owner.setStyleSheet(owner.styleSheet())
        self.help_button.setText("?" if compact else "Ajuda")
        self.help_button.setIconSize(QtCore.QSize(22 if compact else 18, 22 if compact else 18))
        self.help_button.setToolTip("Como começar")

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
        self._last_normal_geometry = QtCore.QRect()
        self._last_non_minimized_maximized = False
        self._frame_checked = False
        self._frame_check_scheduled = False
        self.bridge = bridge
        self.setWindowTitle("Ameno Tools · Cotas")
        self.setObjectName("AmenoMainWindow")
        self.setWindowFlags(QtCore.Qt.WindowType.Window | QtCore.Qt.WindowType.WindowMinimizeButtonHint | QtCore.Qt.WindowType.WindowMaximizeButtonHint | QtCore.Qt.WindowType.WindowCloseButtonHint)
        # A fixed minimum can make the native frame larger than a small or
        # high-DPI monitor. Individual pages own vertical scrolling instead.
        self.setMinimumSize(0, 0)
        self.setWindowIcon(icon("brand/ameno-symbol-red.png"))
        self.setAttribute(QtCore.Qt.WidgetAttribute.WA_DeleteOnClose, True)
        self._authenticate = authenticate
        self._logout_callback = logout
        self.login_page = LoginPage(authenticate)
        self.shell = AppShell(bridge, logout)
        self.stack = QtWidgets.QStackedWidget()
        # The window is the constraint boundary. Let each page scroll instead
        # of exporting its size hint as an implicit native minimum.
        self.stack.setSizePolicy(
            QtWidgets.QSizePolicy.Policy.Ignored,
            QtWidgets.QSizePolicy.Policy.Ignored,
        )
        self.stack.addWidget(self.login_page)
        self.stack.addWidget(self.shell)
        self.setCentralWidget(self.stack)
        # Autodesk's host style may otherwise promote the central size hint to
        # an explicit native minimum when the window is polished.
        if self.layout() is not None:
            self.layout().setSizeConstraint(QtWidgets.QLayout.SizeConstraint.SetNoConstraint)
        self.stack.setCurrentWidget(self.login_page)
        # Keep the host palette untouched: the stylesheet belongs only to
        # this top-level Ameno window and its descendants.
        apply_to(self)
        self._restore_geometry()

    @staticmethod
    def _screen_record(screen) -> tuple[str, str, QtCore.QRect]:
        def text_value(name: str) -> str:
            value = getattr(screen, name, None)
            try:
                return str(value() if callable(value) else value or "")
            except Exception:
                return ""

        return text_value("serialNumber"), text_value("name"), QtCore.QRect(screen.availableGeometry())

    def _screen_records(self, preferred_screen=None) -> list[tuple[str, str, QtCore.QRect]]:
        records = [self._screen_record(screen) for screen in QtGui.QGuiApplication.screens()]
        if preferred_screen is not None:
            preferred = self._screen_record(preferred_screen)
            if preferred not in records:
                records.insert(0, preferred)
        return records

    @staticmethod
    def _bool_setting(value) -> bool:
        if isinstance(value, str):
            return value.strip().lower() in ("1", "true", "yes", "on")
        return bool(value)

    def _restore_geometry(self) -> None:
        preferences = settings()
        screen = self.screen() or QtGui.QGuiApplication.primaryScreen()
        preferred = screen.availableGeometry() if screen is not None else QtCore.QRect(0, 0, 780, 1020)
        records = self._screen_records(screen)
        areas = [record[2] for record in records]
        saved_serial = str(preferences.value("window/screenSerial", "") or "")
        saved_name = str(preferences.value("window/screenName", "") or "")
        matched = next((record for record in records if saved_serial and record[0] == saved_serial), None)
        if matched is None:
            matched = next((record for record in records if saved_name and record[1] == saved_name), None)
        if matched is not None:
            preferred = matched[2]

        native_geometry = preferences.value("window/geometry")
        native_restored = False
        if native_geometry is not None:
            try:
                native_restored = bool(self.restoreGeometry(native_geometry))
            except Exception:
                native_restored = False
        # restoreGeometry may carry an old maximized bit. The explicit setting
        # below is authoritative, and geometry validation operates on a normal
        # window rectangle.
        special_states = (
            QtCore.Qt.WindowState.WindowMinimized
            | QtCore.Qt.WindowState.WindowMaximized
            | QtCore.Qt.WindowState.WindowFullScreen
        )
        self.setWindowState(self.windowState() & ~special_states)
        saved_normal = preferences.value("window/normalGeometry")
        if not isinstance(saved_normal, QtCore.QRect) or not saved_normal.isValid():
            saved_normal = None
        candidate = QtCore.QRect(saved_normal) if saved_normal is not None else (
            QtCore.QRect(self.geometry()) if native_restored else None
        )
        if candidate is not None:
            saved_available = preferences.value("window/screenAvailableGeometry")
            if matched is not None and isinstance(saved_available, QtCore.QRect) and saved_available.isValid():
                candidate = remap_window_geometry(candidate, saved_available, matched[2])
            candidate = recover_window_geometry(candidate, areas, preferred)
            self.setGeometry(candidate)
        else:
            self.setGeometry(initial_window_geometry(preferred))
        self._last_normal_geometry = QtCore.QRect(self.geometry())
        maximized = self._bool_setting(preferences.value("window/maximized", False))
        self._last_non_minimized_maximized = maximized
        if maximized:
            self.setWindowState(self.windowState() | QtCore.Qt.WindowState.WindowMaximized)

    def _save_geometry(self) -> None:
        preferences = settings()
        screen = self.screen() or QtGui.QGuiApplication.primaryScreen()
        records = self._screen_records(screen)
        areas = [record[2] for record in records]
        if not self.isMaximized() and not self.isMinimized() and not self.isFullScreen():
            candidate = QtCore.QRect(self.geometry())
            self._last_normal_geometry = QtCore.QRect(candidate)
        else:
            candidate = QtCore.QRect(self.normalGeometry())
            if not candidate.isValid():
                candidate = QtCore.QRect(self._last_normal_geometry)
        # Do not replace a known-good restore point with an inaccessible frame.
        if visible_enough(candidate, areas):
            preferences.setValue("window/geometry", self.saveGeometry())
            preferences.setValue("window/normalGeometry", candidate)
            selected = max(
                records,
                key=lambda record: candidate.intersected(record[2]).width()
                * candidate.intersected(record[2]).height(),
                default=("", "", QtCore.QRect()),
            )
            preferences.setValue("window/screenAvailableGeometry", selected[2])
            for key, value in (("window/screenSerial", selected[0]), ("window/screenName", selected[1])):
                if value:
                    preferences.setValue(key, value)
                else:
                    preferences.remove(key)
        maximized = self._last_non_minimized_maximized if self.isMinimized() else self.isMaximized()
        preferences.setValue("window/maximized", maximized)
        preferences.sync()

    def _remember_normal_geometry(self) -> None:
        state = self.windowState()
        special = (
            QtCore.Qt.WindowState.WindowMinimized
            | QtCore.Qt.WindowState.WindowMaximized
            | QtCore.Qt.WindowState.WindowFullScreen
        )
        if not bool(state & special) and self.geometry().isValid():
            self._last_normal_geometry = QtCore.QRect(self.geometry())

    def moveEvent(self, event) -> None:  # noqa: N802 - Qt API
        super().moveEvent(event)
        self._remember_normal_geometry()

    def resizeEvent(self, event) -> None:  # noqa: N802 - Qt API
        super().resizeEvent(event)
        self._remember_normal_geometry()

    def changeEvent(self, event) -> None:  # noqa: N802 - Qt API
        super().changeEvent(event)
        if event.type() == QtCore.QEvent.Type.WindowStateChange:
            state = self.windowState()
            if bool(state & QtCore.Qt.WindowState.WindowMinimized):
                old_state = event.oldState() if hasattr(event, "oldState") else QtCore.Qt.WindowState.WindowNoState
                if bool(old_state & QtCore.Qt.WindowState.WindowMaximized):
                    self._last_non_minimized_maximized = True
            else:
                self._last_non_minimized_maximized = bool(state & QtCore.Qt.WindowState.WindowMaximized)
            special = (
                QtCore.Qt.WindowState.WindowMinimized
                | QtCore.Qt.WindowState.WindowMaximized
                | QtCore.Qt.WindowState.WindowFullScreen
            )
            if not bool(state & special) and self.isVisible():
                self._schedule_frame_check()

    def showEvent(self, event) -> None:  # noqa: N802 - Qt API
        super().showEvent(event)
        self._schedule_frame_check()

    def _schedule_frame_check(self) -> None:
        if self._frame_checked or self._frame_check_scheduled or self.isMaximized():
            return
        # Native frame margins are not final during showEvent in 3ds Max.
        # Defer exactly once; this is not polling and never touches the bridge.
        self._frame_check_scheduled = True
        QtCore.QTimer.singleShot(0, self._ensure_frame_visible)

    def _ensure_frame_visible(self) -> None:
        self._frame_check_scheduled = False
        if self._frame_checked or self.isMaximized() or not self.isVisible():
            return
        self._frame_checked = True
        screen = self.screen() or QtGui.QGuiApplication.primaryScreen()
        if screen is None:
            return
        available = screen.availableGeometry()
        frame = self.frameGeometry()
        if available.contains(frame):
            return
        safe_frame = recover_window_geometry(frame, [available], available)
        client = self.geometry()
        horizontal_frame = max(0, frame.width() - client.width())
        vertical_frame = max(0, frame.height() - client.height())
        self.setGeometry(
            safe_frame.left() + (client.left() - frame.left()),
            safe_frame.top() + (client.top() - frame.top()),
            max(1, safe_frame.width() - horizontal_frame),
            max(1, safe_frame.height() - vertical_frame),
        )
        self._remember_normal_geometry()

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
