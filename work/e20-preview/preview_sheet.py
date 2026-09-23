"""Render a contact sheet of the local preview for E20.4 evidence."""
import os
import sys
from dataclasses import replace
from pathlib import Path

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
ROOT = Path.cwd()
sys.path.insert(0, str(ROOT / "Contents" / "python"))
from PySide6 import QtCore, QtGui, QtWidgets  # noqa: E402

from ameno_ui.models import StyleSnapshot  # noqa: E402
from ameno_ui.styles_page import PreviewWidget  # noqa: E402
from ameno_ui.theme import register_fonts  # noqa: E402

app = QtWidgets.QApplication.instance() or QtWidgets.QApplication([])
register_fonts()
out = Path(sys.argv[1])
out.mkdir(parents=True, exist_ok=True)
presets = {
    "arquitetonico": StyleSnapshot("default", "Arquitetônico"),
    "editorial": StyleSnapshot("editorial", "Editorial", font_name="Georgia", font_size=150, text_gap=50,
                               line_thickness=1.2, extension_overhang=60, terminal_type="dot", terminal_size=70),
    "tecnico": StyleSnapshot("technical", "Técnico", font_name="Consolas", font_size=120, text_gap=40,
                             line_thickness=1.8, extension_overhang=60, terminal_type="arrowClosed", terminal_size=110),
}
cases = [(name, style, True, 1.0) for name, style in presets.items()]
cases += [("seta-aberta", replace(presets["tecnico"], terminal_type="arrowOpen"), True, 1.0),
          ("losango", replace(presets["arquitetonico"], terminal_type="diamond"), True, 1.0),
          ("arquitetonico-claro", presets["arquitetonico"], False, 1.0),
          ("tecnico-escuro-cor", replace(presets["tecnico"], annotation_color="230,59,46"), False, 1.0),
          ("arquitetonico-50", presets["arquitetonico"], True, 0.5),
          ("arquitetonico-200", presets["arquitetonico"], True, 2.0),
          ("texto-extremo", replace(presets["arquitetonico"], font_size=5000, text_gap=1000), True, 1.0)]
widget = PreviewWidget()
widget.resize(620, 240)
for name, style, dark, zoom in cases:
    widget.set_model(style, dark, zoom)
    image = QtGui.QImage(620, 240, QtGui.QImage.Format.Format_ARGB32)
    image.fill(QtGui.QColor("#000000"))
    widget.render(image)
    assert image.save(str(out / ("%s.png" % name)))
print("rendered %d" % len(cases))
