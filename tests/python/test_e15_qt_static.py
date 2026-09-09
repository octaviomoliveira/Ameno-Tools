"""Static contract tests that do not create a second QApplication."""

from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
PY_ROOT = ROOT / "Contents" / "python" / "ameno_ui"


def test_python_package_compiles_and_has_required_modules() -> None:
    required = {"__init__.py", "application.py", "auth.py", "bridge.py", "entrypoint.py", "qt_compat.py", "window.py"}
    assert required.issubset({path.name for path in PY_ROOT.iterdir()})
    for path in PY_ROOT.glob("*.py"):
        compile(path.read_text(encoding="utf-8"), str(path), "exec")


def test_new_ui_does_not_import_wpf_or_create_qapplication() -> None:
    source = "\n".join(path.read_text(encoding="utf-8") for path in PY_ROOT.glob("*.py"))
    forbidden = ("System.Windows", "PresentationFramework", "WinForms", "PyQt", "QApplication(")
    assert not any(item in source for item in forbidden)
    assert "QApplication.instance()" in source


def test_auth_token_is_not_serialized_or_logged() -> None:
    source = (PY_ROOT / "auth.py").read_text(encoding="utf-8")
    assert "QSettings" not in source
    assert "logging" not in source
    assert "_token" in source


def test_auth_gateway_failure_returns_safe_error_state() -> None:
    import sys

    sys.path.insert(0, str(ROOT / "Contents" / "python"))
    from ameno_ui.auth import AuthGateway, AuthSession

    class ExplodingGateway(AuthGateway):
        def validate(self, token: str):
            raise RuntimeError("transport failure")

    session = AuthSession()
    result = session.authenticate("secret", ExplodingGateway())
    assert not result.success
    assert not session.authenticated


def test_bootstrap_and_packaging_do_not_load_legacy_presentation() -> None:
    bootstrap = (ROOT / "Contents" / "scripts" / "startup" / "ameno_bootstrap.ms").read_text(encoding="utf-8")
    package_script = (ROOT / "tools" / "package-alpha.ps1").read_text(encoding="utf-8")
    install_script = (ROOT / "tools" / "install-dev.ps1").read_text(encoding="utf-8")
    legacy_modules = (
        "ameno_style_editor_wpf.ms",
        "ameno_cotas_criar_tab.ms",
        "ameno_cotas_estilos_tab.ms",
        "ameno_cotas_editar_tab.ms",
        "ameno_cotas_render_tab.ms",
        "ameno_cotas_window.ms",
        "ameno_main_panel.ms",
    )
    assert not any((f'@"ui\\{name}"' in bootstrap) for name in legacy_modules)
    assert all(name in package_script and name in install_script for name in legacy_modules)
    assert "show_page(self, name: str, refresh: bool = False)" in (PY_ROOT / "window.py").read_text(encoding="utf-8")
