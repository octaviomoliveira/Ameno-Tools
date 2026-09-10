"""Render the E19 Estilo page at the 980x720 acceptance size."""

from __future__ import annotations

import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "work" / "e19-visual"
os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
sys.path.insert(0, str(ROOT / "Contents" / "python"))

from PySide6 import QtGui, QtWidgets  # noqa: E402

from ameno_ui.models import StyleSnapshot  # noqa: E402
from ameno_ui.window import AmenoMainWindow  # noqa: E402


class GalleryBridge:
    def cancel_interactive(self):
        return True


def main() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    app = QtWidgets.QApplication.instance() or QtWidgets.QApplication([])
    window = AmenoMainWindow(GalleryBridge(), lambda _token: None, lambda: None)
    window.resize(980, 720)
    page = window.shell.pages["styles"]
    page.load_styles(
        [
            StyleSnapshot(
                "architectural",
                "Arquitetônico",
                font_name="Arial",
                font_size=98.0,
                text_gap=60.0,
                annotation_color="239,68,68",
                in_use=4,
            )
        ]
    )
    window.show_application("styles")
    window.show()
    app.processEvents()
    targets = []
    for width, height, name in (
        (980, 720, "02-estilo-980x720.png"),
        (780, 560, "03-estilo-780x560.png"),
        (780, 720, "04-estilo-default-780x720.png"),
    ):
        window.resize(width, height)
        app.processEvents()
        image = QtGui.QImage(window.size(), QtGui.QImage.Format.Format_ARGB32)
        image.fill(QtGui.QColor("#0A0A0A"))
        window.render(image)
        target = OUTPUT / name
        if not image.save(str(target)):
            raise RuntimeError("Falha ao salvar " + str(target))
        targets.append(target)
    window.close()
    app.processEvents()
    for target in targets:
        print(target)


if __name__ == "__main__":
    main()
