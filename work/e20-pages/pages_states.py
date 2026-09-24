"""Render Revisar, Exportar and Configurações for E20.6 evidence (no scene)."""
import os
import sys
from pathlib import Path

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
ROOT = Path.cwd()
sys.path.insert(0, str(ROOT / "tests" / "python"))
sys.path.insert(0, str(ROOT / "Contents" / "python"))
from PySide6 import QtGui  # noqa: E402

from test_e20_pages_contracts import AUDIT, _settle, _window  # noqa: E402

out = Path(sys.argv[1])
out.mkdir(parents=True, exist_ok=True)


def shot(app, window, name):
    _settle(app)
    image = QtGui.QImage(window.width(), window.height(), QtGui.QImage.Format.Format_ARGB32)
    image.fill(QtGui.QColor("#0A0A0A"))
    window.render(image)
    assert image.save(str(out / name))


for width, height in ((780, 1020), (440, 1020)):
    size = "%dx%d" % (width, height)
    with _window(width, height) as (app, window, _bridge):
        for key in ("edit", "render", "config"):
            window.shell.show_page(key)
            shot(app, window, "%s-%s.png" % (key, size))
        window.shell.pages["edit"]._load(AUDIT)
        window.shell.show_page("edit")
        shot(app, window, "edit-loaded-%s.png" % size)
print("ok")
