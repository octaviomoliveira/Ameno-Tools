"""Small Qt seam for the first supported host (3ds Max 2026/PySide6).

No widget imports PySide directly. A PySide2 adapter will be added only after
the 2026 candidate is accepted on a real host.
"""

try:
    from PySide6 import QtCore, QtGui, QtWidgets
except Exception as exc:  # pragma: no cover - exercised only outside Max
    raise ImportError("Ameno requer o PySide6 embarcado no 3ds Max 2026: %s" % exc)


def application():
    app = QtWidgets.QApplication.instance()
    if app is None:
        raise RuntimeError("O 3ds Max não forneceu um QApplication existente.")
    return app


def max_parent():
    try:
        import qtmax

        return qtmax.GetQMaxMainWindow()
    except Exception:
        return None


def enum_value(value):
    """Return a Qt enum in a form accepted by both property setters used here."""
    return value


Signal = QtCore.Signal
Slot = QtCore.Slot
