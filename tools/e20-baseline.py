"""Capture E20.0 evidence or run a complete, explicit subset of Python gates.

Use an external Qt 6.5.3 runtime with the offscreen plugin. The Max-distributed
Qt only supplies qwindows.dll; this script never installs into Autodesk or
loads the scene. --suite e20 intentionally returns nonzero until defects are
fixed. --suite legacy is the unchanged pre-E20 regression baseline.
"""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import platform
import subprocess
import struct
import sys
import tempfile
import time
import traceback

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "Contents" / "python"))
os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")


def manifest(output: Path, installed: Path | None) -> int:
    """Fingerprint baseline inputs; no Qt, scene access or installation writes."""
    def sha(path: Path) -> str:
        return hashlib.sha256(path.read_bytes()).hexdigest()

    screenshots = []
    for path in sorted((output / "user").glob("*.png")):
        header = path.read_bytes()[:24]
        assert header[:8] == b"\x89PNG\r\n\x1a\n", path
        screenshots.append({"file": str(path.relative_to(output)), "sha256": sha(path),
                            "image_pixels": list(struct.unpack(">II", header[16:24]))})
    sources = []
    for path in sorted((ROOT / "Contents").rglob("*")):
        if not path.is_file() or path.suffix not in (".py", ".ms", ".mcr"):
            continue
        relative = path.relative_to(ROOT / "Contents")
        row = {"file": relative.as_posix(), "source_sha256": sha(path)}
        if installed:
            target = installed / "Contents" / relative
            row["installed_exists"] = target.is_file()
            if target.is_file():
                row["installed_sha256"] = sha(target)
                normalize = lambda item: item.read_text(encoding="utf-8-sig").replace("\r\n", "\n")
                row["equal_ignoring_eol_and_bom"] = normalize(path) == normalize(target)
        sources.append(row)
    result = {"head": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
              "installed_root": str(installed) if installed else None,
              "note": "Read-only content comparison; normalized equality is NOT binary installation parity.",
              "user_screenshots": screenshots, "production_sources": sources}
    output.mkdir(parents=True, exist_ok=True)
    (output / "inputs.json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    mismatches = [row for row in sources if row.get("equal_ignoring_eol_and_bom") is False]
    print("MANIFEST %d screenshots, %d source files, %d normalized installed mismatches"
          % (len(screenshots), len(sources), len(mismatches)))
    return 1 if mismatches else 0


def run_tests(suite: str, report: Path) -> int:
    results = []
    files = sorted((ROOT / "tests" / "python").glob("test_*.py"))
    if suite == "legacy":
        files = [path for path in files if not path.name.startswith("test_e20_")]
    elif suite == "e20-window":
        files = [path for path in files if path.name == "test_e20_window_contracts.py"]
    elif suite == "e20-shell":
        files = [path for path in files if path.name == "test_e20_shell_contracts.py"]
    elif suite == "e20-cotar":
        files = [path for path in files if path.name == "test_e20_cotar_contracts.py"]
    elif suite == "e20-styles":
        files = [path for path in files if path.name == "test_e20_styles_contracts.py"]
    elif suite == "e20-preview":
        files = [path for path in files if path.name == "test_e20_preview_contracts.py"]
    else:
        files = [path for path in files if path.name.startswith("test_e20_")]
    with tempfile.TemporaryDirectory(prefix="ameno-e20-tests-") as directory:
        os.environ["AMENO_SETTINGS_FILE"] = str(Path(directory) / "isolated.ini")
        for path in files:
            spec = importlib.util.spec_from_file_location(path.stem, path)
            module = importlib.util.module_from_spec(spec)
            sys.modules[path.stem] = module
            spec.loader.exec_module(module)
            for name in sorted(item for item in vars(module) if item.startswith("test_")):
                label = path.name + "::" + name
                print("RUN " + label, flush=True)
                start = time.perf_counter()
                error = ""
                try:
                    getattr(module, name)()
                except Exception:
                    error = traceback.format_exc()
                results.append({"test": label, "status": "FAIL" if error else "PASS",
                                "seconds": round(time.perf_counter() - start, 4), "error": error})
                print(("FAIL " + error.splitlines()[-1]) if error else "PASS", flush=True)
    failed = sum(result["status"] == "FAIL" for result in results)
    from PySide6 import QtCore, __version__ as pyside_version

    runtime_files = sorted((ROOT / "Contents" / "python" / "ameno_ui").glob("*.py"))
    report.parent.mkdir(parents=True, exist_ok=True)
    report.write_text(json.dumps({"suite": suite, "python": platform.python_version(),
        "head": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
        "pyside": pyside_version, "qt": QtCore.qVersion(),
        "test_sources": {path.name: hashlib.sha256(path.read_bytes()).hexdigest() for path in files},
        "runtime_sources": {
            str(path.relative_to(ROOT)).replace("\\", "/"): hashlib.sha256(path.read_bytes()).hexdigest()
            for path in runtime_files
        },
        "font_dpi_override": os.environ.get("QT_FONT_DPI"), "tests": results,
        "passed": len(results) - failed, "failed": failed}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("RESULT %s: %d PASS / %d FAIL" % (suite, len(results) - failed, failed), flush=True)
    return 1 if failed else 0


def capture(output: Path) -> int:
    from PySide6 import QtCore, QtGui, QtWidgets, __version__ as pyside_version
    from ameno_ui.components import ChoiceCard
    from ameno_ui.models import StyleSnapshot
    from ameno_ui.window import AmenoMainWindow

    class LocalBridge:
        def __init__(self):
            self.calls = []

        def cancel_interactive(self):
            self.calls.append("cancel")
            return True

        def __getattr__(self, name):
            raise AssertionError("Unexpected scene access in local capture: " + name)

    def rect(widget, target):
        point = widget.mapTo(target, QtCore.QPoint(0, 0))
        return [point.x(), point.y(), widget.width(), widget.height()]

    def text_metrics(label):
        area = label.contentsRect()
        metrics = label.fontMetrics()
        if label.wordWrap():
            required = metrics.boundingRect(QtCore.QRect(0, 0, area.width(), 10000),
                int(QtCore.Qt.TextFlag.TextWordWrap), label.text()).size()
        else:
            required = QtCore.QSize(metrics.horizontalAdvance(label.text()), metrics.height())
        return {"text": label.text(), "available": [area.width(), area.height()],
                "required": [required.width(), required.height()],
                "fits": required.width() <= area.width() and required.height() <= area.height()}

    output.mkdir(parents=True, exist_ok=True)
    app = QtWidgets.QApplication.instance() or QtWidgets.QApplication([])
    bridge = LocalBridge()
    entries = []
    with tempfile.TemporaryDirectory(prefix="ameno-e20-gallery-") as directory:
        os.environ["AMENO_SETTINGS_FILE"] = str(Path(directory) / "isolated.ini")
        window = AmenoMainWindow(bridge, lambda _token: None, lambda: None)
        window.shell.pages["styles"].load_styles([StyleSnapshot("architectural", "Arquitetônico")])
        window.shell.pages["create"].tool_choice.set_value("continuous", emit=True)
        initial_size = [window.width(), window.height()]
        window.show_application("create")
        window.show()
        try:
            for width, height in ((780, 720), (780, 1020), (980, 720), (780, 560), (1280, 800)):
                window.resize(width, height)
                for key in ("create", "styles", "edit", "render", "config"):
                    window.shell.show_page(key)
                    for _ in range(3):
                        app.processEvents()
                    page = window.shell.pages[key]
                    view = window.shell.page_views[key]
                    target = output / ("%s-%dx%d.png" % (key, width, height))
                    ratio = window.devicePixelRatioF()
                    picture = QtGui.QImage(round(window.width() * ratio), round(window.height() * ratio),
                                           QtGui.QImage.Format.Format_ARGB32)
                    picture.setDevicePixelRatio(ratio)
                    picture.fill(QtGui.QColor("#0A0A0A"))
                    window.render(picture)
                    assert picture.save(str(target)), str(target)
                    entry = {"file": target.name, "sha256": hashlib.sha256(target.read_bytes()).hexdigest(),
                        "page": key, "requested_size": [width, height], "size": [window.width(), window.height()],
                        "image_pixels": [picture.width(), picture.height()],
                        "viewport_size": [view.viewport().width(), view.viewport().height()],
                        "sidebar_width": window.shell.sidebar.width(),
                        "scroll_max": [view.horizontalScrollBar().maximum(), view.verticalScrollBar().maximum()],
                        "logical_dpi": window.logicalDpiY(), "dpr": window.devicePixelRatioF()}
                    if key == "create":
                        entry["cta_rect"] = rect(page.start_button, view.viewport())
                        entry["cta_fully_visible"] = view.viewport().rect().contains(QtCore.QRect(*entry["cta_rect"]))
                        entry["card_text"] = [text_metrics(label) for card in page.findChildren(ChoiceCard)
                            for label in (card.title_label, card.hint_label)]
                    if key == "styles":
                        entry["workspace_mode"] = page._workspace_mode
                        entry["preview_rect"] = rect(page.preview_box, view.viewport())
                        entry["footer_rect"] = rect(page.footer, view.viewport())
                        entry["controls_viewport"] = [page.controls_scroll.viewport().width(), page.controls_scroll.viewport().height()]
                        entry["controls_scroll_max"] = [page.controls_scroll.horizontalScrollBar().maximum(), page.controls_scroll.verticalScrollBar().maximum()]
                    entries.append(entry)
            assert bridge.calls == [], bridge.calls
        finally:
            window.close()
            app.processEvents()
    git_head = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    report = {"head": git_head, "python": platform.python_version(), "pyside": pyside_version,
        "qt": QtCore.qVersion(), "platform": app.platformName(),
        "font_dpi_override": os.environ.get("QT_FONT_DPI"), "initial_size": initial_size,
        "scope": "Offscreen model/Qt evidence; not human acceptance in 3ds Max.", "captures": entries}
    (output / "metrics.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print("CAPTURED %d pages; metrics: %s" % (len(entries), output / "metrics.json"), flush=True)
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--suite",
        choices=("legacy", "e20", "e20-window", "e20-shell", "e20-cotar", "e20-styles", "e20-preview"),
    )
    parser.add_argument("--report", type=Path, default=ROOT / "work/e20-baseline/python-results.json")
    parser.add_argument("--capture", type=Path)
    parser.add_argument("--manifest", type=Path)
    parser.add_argument("--installed", type=Path, help="Optional existing ApplicationPlugins package, read-only")
    args = parser.parse_args()
    if args.suite:
        return run_tests(args.suite, args.report)
    if args.capture:
        return capture(args.capture)
    if args.manifest:
        return manifest(args.manifest, args.installed)
    parser.error("Use --suite, --capture or --manifest")


if __name__ == "__main__":
    raise SystemExit(main())
