"""Primitive, exception-safe calls into the MAXScript runtime."""

from __future__ import annotations

from typing import Any, Dict, Iterable, List, Optional, Tuple

from .models import AuditSnapshot, CreateSnapshot, SceneSnapshot, StyleSnapshot, _items


class BridgeError(RuntimeError):
    def __init__(self, code: str, message: str) -> None:
        super().__init__(message)
        self.code = code
        self.message = message


def _runtime():
    try:
        from pymxs import runtime as rt
    except Exception as exc:  # pragma: no cover - only outside Max
        raise BridgeError("hostUnavailable", "O Python do 3ds Max não está disponível: %s" % exc)
    return rt


def _plain(value: Any) -> Any:
    if isinstance(value, (list, tuple)):
        return [_plain(item) for item in value]
    try:
        if value.__class__.__name__ in ("Array", "Point3"):
            return [_plain(item) for item in value]
    except Exception:
        pass
    return value


def _result(value: Any) -> Tuple[bool, str, str, Any]:
    data = _items(_plain(value))
    if len(data) < 3:
        raise BridgeError("invalidResponse", "A ponte retornou uma resposta inválida.")
    ok = bool(data[0])
    code = str(data[1] or "unknown")
    message = str(data[2] or "")
    payload = data[3] if len(data) > 3 else None
    if not ok:
        raise BridgeError(code, message)
    return ok, code, message, payload


class UiBridge:
    """The only scene-facing object retained by the Qt application."""

    def __init__(self) -> None:
        self._rt = None

    @property
    def rt(self):
        if self._rt is None:
            self._rt = _runtime()
        return self._rt

    def _service(self):
        try:
            service = getattr(self.rt, "AmenoUiBridge", None)
        except Exception:
            service = None
        if service is None:
            raise BridgeError("bridgeUnavailable", "A ponte Python/Qt do Ameno não foi carregada.")
        return service

    def _call(self, name: str, *args, **kwargs) -> Any:
        try:
            method = getattr(self._service(), name)
            return method(*args, **kwargs)
        except BridgeError:
            raise
        except Exception as exc:
            raise BridgeError("bridgeException", str(exc))

    def refresh(self) -> Dict[str, Any]:
        _, code, message, payload = _result(self._call("refreshSnapshot"))
        data = _items(payload)
        data += [None] * (4 - len(data))
        return {
            "message": message,
            "scene": SceneSnapshot.from_wire(data[0]),
            "create": CreateSnapshot.from_wire(data[1]),
            "audit": AuditSnapshot.from_wire(data[2]),
            "styles": [StyleSnapshot.from_wire(item) for item in _items(data[3])],
        }

    def scene(self) -> SceneSnapshot:
        return SceneSnapshot.from_wire(self._call("sceneSnapshot"))

    def create(self) -> CreateSnapshot:
        return CreateSnapshot.from_wire(self._call("createSnapshot"))

    def selected_audit(self) -> Optional[AuditSnapshot]:
        return AuditSnapshot.from_wire(self._call("selectedAuditSnapshot"))

    def styles(self) -> List[StyleSnapshot]:
        return [StyleSnapshot.from_wire(item) for item in _items(self._call("stylesSnapshot"))]

    def prepare_scene(self) -> Dict[str, Any]:
        _, code, message, payload = _result(self._call("prepareSceneCommand"))
        data = _items(payload)
        data += [None] * (4 - len(data))
        return {"code": code, "message": message, "status": str(data[0] or "unknown"), "label": str(data[1] or ""), "detail": str(data[2] or ""), "scene": SceneSnapshot.from_wire(data[3])}

    def set_create_settings(self, mode: str, plane: str, style_id: str, unit: str, precision: int, follow_line: bool) -> CreateSnapshot:
        _, _, _, payload = _result(self._call("setCreateSettings", mode, plane, style_id, unit, int(precision), bool(follow_line)))
        return CreateSnapshot.from_wire(payload)

    def start_individual(self) -> Dict[str, Any]:
        _, _, message, payload = _result(self._call("runIndividual"))
        data = _items(payload)
        data += [None] * 3
        return {"message": message, "scene": SceneSnapshot.from_wire(data[0]), "create": CreateSnapshot.from_wire(data[1]), "audit": AuditSnapshot.from_wire(data[2])}

    def start_continuous(self) -> Dict[str, Any]:
        _, _, message, payload = _result(self._call("runContinuous"))
        data = _items(payload)
        data += [None] * 3
        return {"message": message, "scene": SceneSnapshot.from_wire(data[0]), "create": CreateSnapshot.from_wire(data[1]), "audit": AuditSnapshot.from_wire(data[2])}

    def cancel_interactive(self) -> bool:
        _, _, _, payload = _result(self._call("cancelInteractiveCommand"))
        return bool(payload)

    def _count_command(self, name: str) -> int:
        _, _, _, payload = _result(self._call(name))
        try:
            return int(payload or 0)
        except Exception:
            return 0

    def repair_all(self) -> int:
        return self._count_command("repairAllCommand")

    def repair_orphans(self) -> int:
        return self._count_command("repairOrphansCommand")

    def delete_selection(self) -> int:
        return self._count_command("deleteSelectionCommand")

    def clear_orphans(self) -> int:
        return self._count_command("clearOrphansCommand")

    def delete_all(self) -> int:
        return self._count_command("deleteAllCommand")

    def save_style(self, style: StyleSnapshot) -> int:
        _, _, _, payload = _result(self._call("saveStyleCommand", style.style_id, style.name, style.font_name, style.font_size, style.bold, style.italic, style.tracking, style.text_gap, style.line_thickness, style.extension_overhang, style.extension_gap, style.terminal_type, style.terminal_size, style.text_mask_enabled, style.annotation_color, style.text_color, style.terminal_placement, style.terminal_angle, style.preview_scale))
        try:
            return int(payload or 0)
        except Exception:
            return 0

    def new_style(self, base_style_id: str, name: str) -> StyleSnapshot:
        _, _, _, payload = _result(self._call("newStyleCommand", base_style_id, name))
        return StyleSnapshot.from_wire(payload)

    def delete_style(self, style_id: str) -> bool:
        _, _, _, payload = _result(self._call("deleteStyleCommand", style_id))
        return bool(payload)

    def apply_style(self, style_id: str, all_dimensions: bool = False) -> int:
        _, _, _, payload = _result(self._call("applyStyleCommand", style_id, bool(all_dimensions)))
        try:
            return int(payload or 0)
        except Exception:
            return 0

    def edit_selected(self, mode: str, rounding_mm: float, manual_value: str, manual_text: str, reason: str) -> Optional[AuditSnapshot]:
        _, _, _, payload = _result(self._call("selectedModeCommand", mode, float(rounding_mm), manual_value, manual_text, reason))
        return AuditSnapshot.from_wire(payload)

    def restore_selected(self) -> Optional[AuditSnapshot]:
        _, _, _, payload = _result(self._call("restoreSelectedCommand"))
        return AuditSnapshot.from_wire(payload)

    def apply_selected_style(self, style_id: str) -> bool:
        _, _, _, payload = _result(self._call("applySelectedStyleCommand", style_id))
        return bool(payload)

    def select_anchors(self) -> bool:
        _, _, _, payload = _result(self._call("selectAnchorsCommand"))
        return bool(payload)

    def default_render_path(self) -> str:
        return str(self._call("defaultRenderPath") or "")

    def render(self, output_path: str, selection: str, dimensions_only: bool) -> Tuple[str, str]:
        _, _, _, payload = _result(self._call("renderCommand", output_path, selection, bool(dimensions_only)))
        data = _items(payload)
        data += ["", output_path]
        return str(data[0] or ""), str(data[1] or output_path)

    def diagnostic(self) -> str:
        _, _, _, payload = _result(self._call("diagnosticCommand"))
        return str(payload or "")
