"""Render the E19 Cotar page at the user's 980x720 acceptance size."""

from __future__ import annotations

import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "work" / "e19-visual"
os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
sys.path.insert(0, str(ROOT / "Contents" / "python"))

from PySide6 import QtGui, QtWidgets  # noqa: E402

from ameno_ui.models import CreateSnapshot, SceneSnapshot, StyleSnapshot  # noqa: E402
from ameno_ui.window import AmenoMainWindow  # noqa: E402


class GalleryBridge:
    def cancel_interactive(self):
        return True


def main() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    app = QtWidgets.QApplication.instance() or QtWidgets.QApplication([])
    window = AmenoMainWindow(GalleryBridge(), lambda _token: None, lambda: None)
    window.resize(980, 720)
    window.show_application("create")
    page = window.shell.pages["create"]
    page.load_styles([StyleSnapshot("architectural", "Arquitetônico")])
    page.load_snapshot(
        {
            "scene": SceneSnapshot(
                status="ready",
                status_label="Cena pronta",
                detail="AMENO_COTAS · AMENO_SYSTEM",
                dimension_count=0,
            ),
            "create": CreateSnapshot(style_id="architectural", unit="meters", precision=2),
        }
    )
    page.tool_choice.set_value("continuous", emit=True)
    window.show()
    app.processEvents()
    image = QtGui.QImage(window.size(), QtGui.QImage.Format.Format_ARGB32)
    image.fill(QtGui.QColor("#0A0A0A"))
    window.render(image)
    target = OUTPUT / "01-cotar-980x720.png"
    if not image.save(str(target)):
        raise RuntimeError("Falha ao salvar " + str(target))
    window.close()
    app.processEvents()
    print(target)


if __name__ == "__main__":
    main()
