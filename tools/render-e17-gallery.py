"""Render deterministic offscreen E17 screenshots for visual review."""

from __future__ import annotations

import os
import sys
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "work" / "e17-visual"
SETTINGS = Path(tempfile.gettempdir()) / ("ameno-e17-gallery-%d.ini" % os.getpid())
os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
os.environ["AMENO_SETTINGS_FILE"] = str(SETTINGS)
sys.path.insert(0, str(ROOT / "Contents" / "python"))

from PySide6 import QtGui, QtWidgets  # noqa: E402

from ameno_ui.models import AuditSnapshot, CreateSnapshot, SceneSnapshot, StyleSnapshot  # noqa: E402
from ameno_ui.window import AmenoMainWindow  # noqa: E402


class GalleryBridge:
    def cancel_interactive(self):
        return True


def capture(window: QtWidgets.QWidget, name: str) -> None:
    image = QtGui.QImage(window.size(), QtGui.QImage.Format.Format_ARGB32)
    image.fill(QtGui.QColor("#0A0A0A"))
    window.render(image)
    if not image.save(str(OUTPUT / (name + ".png"))):
        raise RuntimeError("Falha ao salvar %s" % name)


def main() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    app = QtWidgets.QApplication.instance() or QtWidgets.QApplication([])
    window = AmenoMainWindow(GalleryBridge(), lambda _token: None, lambda: None)
    window.resize(1120, 800)
    window.show()
    app.processEvents()
    capture(window, "01-login")

    style = StyleSnapshot(
        "architectural",
        "Arquitetônico",
        font_name="Arial",
        font_size=140.0,
        text_gap=60.0,
        line_thickness=1.5,
        extension_overhang=80.0,
        terminal_type="tick",
        terminal_size=100.0,
        annotation_color="232,232,224",
        in_use=7,
    )
    window.shell.pages["create"].load_styles([style])
    window.shell.pages["create"].load_snapshot(
        {
            "scene": SceneSnapshot(status="ready", status_label="Pronta", detail="Camadas e materiais disponíveis", dimension_count=7),
            "create": CreateSnapshot(style_id="architectural", unit="meters", precision=2),
        }
    )
    window.shell.pages["styles"].load_styles([style])
    window.shell.pages["edit"]._load(
        AuditSnapshot(
            "AMENO-7F3A",
            "measured",
            3500.0,
            3500.0,
            0.0,
            "3,50 m",
            "3,50 m",
            "0 mm",
            "",
            False,
            "vertex",
            "2 vértices vinculados",
            False,
            "",
        )
    )
    render = window.shell.pages["render"]
    render.renderer.setText("Arnold")
    render.renderer_state.setText("Disponível")
    render.path.setText("C:/Projeto/entrega/cotas.png")

    window.show_application("create")
    for key, number in (("create", "02"), ("styles", "03"), ("edit", "04"), ("render", "05"), ("config", "06")):
        window.shell.show_page(key)
        app.processEvents()
        capture(window, "%s-%s" % (number, key))
    window.close()
    app.processEvents()
    try:
        SETTINGS.unlink()
    except FileNotFoundError:
        pass
    print("Galeria E17: %s" % OUTPUT)


if __name__ == "__main__":
    main()
