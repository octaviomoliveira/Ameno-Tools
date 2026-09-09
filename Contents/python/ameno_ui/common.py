"""Presentation helpers kept independent from scene access."""

from __future__ import annotations

from .qt_compat import QtCore, QtGui, QtWidgets


def button(text: str, slot=None, primary: bool = False) -> QtWidgets.QPushButton:
    widget = QtWidgets.QPushButton(text)
    widget.setMinimumHeight(32)
    if primary:
        widget.setProperty("primary", True)
    if slot is not None:
        widget.clicked.connect(slot)
    return widget


def group(title: str) -> QtWidgets.QGroupBox:
    box = QtWidgets.QGroupBox(title)
    box.setObjectName("Card")
    return box


def scroll(widget: QtWidgets.QWidget) -> QtWidgets.QScrollArea:
    area = QtWidgets.QScrollArea()
    area.setWidgetResizable(True)
    area.setFrameShape(QtWidgets.QFrame.Shape.NoFrame)
    area.setWidget(widget)
    return area


def message_label() -> QtWidgets.QLabel:
    label = QtWidgets.QLabel()
    label.setWordWrap(True)
    label.setTextInteractionFlags(QtCore.Qt.TextInteractionFlag.TextSelectableByMouse)
    label.setObjectName("Status")
    return label


def set_message(label: QtWidgets.QLabel, text: str, error: bool = False) -> None:
    label.setText(text)
    label.setProperty("error", bool(error))
    label.style().unpolish(label)
    label.style().polish(label)


def set_bridge_error(label: QtWidgets.QLabel, error, context: str = "Não foi possível concluir a ação.") -> None:
    """Translate bridge codes into an operational next step.

    The original detail remains available as a selectable tooltip for support,
    while the main surface avoids presenting runtime jargon as instruction.
    """
    code = str(getattr(error, "code", "unknown") or "unknown")
    detail = str(getattr(error, "message", "") or "").strip()
    if code == "noSelection":
        guidance = "Selecione uma cota Ameno na viewport e tente novamente."
    elif code == "busy":
        guidance = "Finalize ou cancele a operação atual antes de iniciar outra."
    elif code in ("runtimeUnavailable", "bridgeUnavailable", "toolUnavailable", "styleServiceUnavailable", "hostUnavailable"):
        guidance = "O Ameno não terminou de carregar. Feche esta janela e reinicie o 3ds Max."
    elif code == "styleProtected":
        guidance = "O estilo padrão é protegido. Duplique-o para criar uma variação."
    elif code == "renderFailed" and "isolat" in detail.lower():
        guidance = detail
    else:
        guidance = context + " Tente novamente; se persistir, copie o diagnóstico em Configuração."
    label.setToolTip("Código: %s\nDetalhe: %s" % (code, detail or "não informado"))
    label.setProperty("errorCode", code)
    set_message(label, guidance, error=True)
