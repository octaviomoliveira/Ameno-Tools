"""Compose before (E20.0 baseline) and after captures side by side."""
import json, os, sys
from pathlib import Path
os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
sys.path.insert(0, str(Path.cwd() / "Contents" / "python"))
from PySide6 import QtCore, QtGui, QtWidgets
from ameno_ui.theme import register_fonts
app = QtWidgets.QApplication.instance() or QtWidgets.QApplication([])
ui_font, _mono = register_fonts()
before, after, out = (Path(p) for p in sys.argv[1:4])
out.mkdir(parents=True, exist_ok=True)
rows = []
for image_path in sorted(after.glob("*.png")):
    old = before / image_path.name
    if not old.exists():
        continue
    a, b = QtGui.QImage(str(old)), QtGui.QImage(str(image_path))
    gap, label_h = 24, 28
    canvas = QtGui.QImage(a.width() + b.width() + gap, max(a.height(), b.height()) + label_h, QtGui.QImage.Format.Format_ARGB32)
    canvas.fill(QtGui.QColor("#050505"))
    painter = QtGui.QPainter(canvas)
    painter.setFont(QtGui.QFont(ui_font, 11))
    painter.setPen(QtGui.QColor("#E8E8E0"))
    painter.drawText(8, 19, "ANTES (E20.0) · %s · %dx%d" % (image_path.stem, a.width(), a.height()))
    painter.drawText(a.width() + gap + 8, 19, "DEPOIS (E20.7) · %dx%d" % (b.width(), b.height()))
    painter.drawImage(0, label_h, a)
    painter.drawImage(a.width() + gap, label_h, b)
    painter.end()
    target = out / image_path.name
    canvas.save(str(target))
    rows.append({"file": target.name, "before": [a.width(), a.height()], "after": [b.width(), b.height()]})
(out / "index.json").write_text(json.dumps(rows, indent=2) + "\n", encoding="utf-8")
print("composed %d" % len(rows))
