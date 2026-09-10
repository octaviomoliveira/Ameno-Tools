"""Render the E18 Qt pages to a disposable visual-review gallery."""

from __future__ import annotations

import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "work" / "e18-visual"
os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
sys.path.insert(0, str(ROOT / "Contents" / "python"))

from PySide6 import QtGui, QtWidgets  # noqa: E402

from ameno_ui.models import CreateSnapshot, SceneSnapshot, StyleSnapshot  # noqa: E402
from ameno_ui.window import AmenoMainWindow  # noqa: E402


class GalleryBridge:
    def cancel_interactive(self):
        return True


def capture(window: QtWidgets.QWidget, name: str) -> None:
    image = QtGui.QImage(window.size(), QtGui.QImage.Format.Format_ARGB32)
    image.fill(QtGui.QColor("#0A0A0A"))
    window.render(image)
    if not image.save(str(OUTPUT / (name + ".png"))):
        raise RuntimeError("Falha ao salvar " + name)


def main() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    app = QtWidgets.QApplication.instance() or QtWidgets.QApplication([])
    window = AmenoMainWindow(GalleryBridge(), lambda _token: None, lambda: None)
    window.resize(1120, 760)
    window.show_application("create")
    window.show()
    app.processEvents()
    capture(window, "01-create")
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
            "scene": SceneSnapshot(status="ready", status_label="Pronta", dimension_count=7),
            "create": CreateSnapshot(style_id="architectural", unit="meters", precision=2),
        }
    )
    window.shell.pages["styles"].load_styles([style])
    for number, key in (("02", "styles"), ("03", "edit"), ("04", "render"), ("05", "config")):
        window.shell.show_page(key)
        app.processEvents()
        capture(window, number + "-" + key)
    window.close()
    app.processEvents()
    print("Galeria E18: " + str(OUTPUT))


if __name__ == "__main__":
    main()
