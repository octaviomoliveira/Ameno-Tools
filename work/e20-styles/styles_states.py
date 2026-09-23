"""Render Estilos states for E20.5 evidence (Qt offscreen, no scene)."""
import os
import sys
from pathlib import Path

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
ROOT = Path.cwd()
sys.path.insert(0, str(ROOT / "tests" / "python"))
sys.path.insert(0, str(ROOT / "Contents" / "python"))
from PySide6 import QtGui  # noqa: E402

from test_e20_styles_contracts import _page  # noqa: E402

out = Path(sys.argv[1])
out.mkdir(parents=True, exist_ok=True)


def shot(app, window, name):
    for _ in range(3):
        app.processEvents()
    image = QtGui.QImage(window.width(), window.height(), QtGui.QImage.Format.Format_ARGB32)
    image.fill(QtGui.QColor("#0A0A0A"))
    window.render(image)
    assert image.save(str(out / name))


for width, height in ((780, 1020), (980, 720)):
    size = "%dx%d" % (width, height)
    with _page(width, height) as (app, window, page, _bridge):
        shot(app, window, "styles-clean-%s.png" % size)
        page.font_size.setValue(200)
        shot(app, window, "styles-dirty-%s.png" % size)
        page.unit.setCurrentIndex(page.unit.findData("cm"))
        page.text_section.toggle.click() if page.text_section.toggle.isChecked() else None
        page.terminals_section.toggle.click()
        page.terminal.setCurrentIndex(page.terminal.findData("diamond"))
        shot(app, window, "styles-terminals-cm-%s.png" % size)
        page.apply_button.click()
        shot(app, window, "styles-saved-applied-%s.png" % size)
print("ok")
