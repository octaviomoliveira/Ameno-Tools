"""E18.10 package and asset contracts."""

from __future__ import annotations

import os
import sys
from pathlib import Path
from xml.etree import ElementTree

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")
ROOT = Path(__file__).resolve().parents[2]
PY_ROOT = ROOT / "Contents" / "python" / "ameno_ui"


def test_new_e18_modules_and_icons_are_inside_the_package_tree() -> None:
    expected = (
        "style_draft.py",
        "parameter_control.py",
        "dimension_preview.py",
        "responsive.py",
        "page_scaffold.py",
    )
    for name in expected:
        assert (PY_ROOT / name).is_file(), name
    for name in ("cotar", "aparencia", "revisar", "exportar", "configuracao", "ajuda"):
        path = PY_ROOT / "assets" / "icons" / (name + ".svg")
        assert path.is_file(), path
        content = path.read_text(encoding="utf-8")
        assert "<svg" in content and "viewBox" in content
        # The XML namespace is a standards-mandated URL; only reject remote
        # resource references that could make the icon depend on the network.
        assert "href=\"http" not in content and "href=\"https" not in content


def test_package_targets_only_max_2026_and_still_excludes_legacy_wpf() -> None:
    manifest = ElementTree.parse(ROOT / "PackageContents.xml").getroot()
    package = manifest
    assert package.tag == "ApplicationPackage"
    assert package.attrib.get("AutodeskProduct") == "3ds Max"
    for component in package.findall("./Components/Component"):
        requirements = component.find("RuntimeRequirements")
        assert requirements is not None
        assert requirements.findtext("SeriesMin") == "2026"
        assert requirements.findtext("SeriesMax") == "2026"
    source = "\n".join(path.read_text(encoding="utf-8") for path in PY_ROOT.glob("*.py"))
    assert "ameno_style_editor_wpf" not in source


def test_packaging_scripts_copy_contents_and_remove_wpf_cache() -> None:
    for name in ("package-alpha.ps1", "install-dev.ps1"):
        source = (ROOT / "tools" / name).read_text(encoding="utf-8")
        assert "Copy-Item" in source and "Contents" in source
        assert "legacyWpfFiles" in source
        assert "pythonCacheDir" in source
