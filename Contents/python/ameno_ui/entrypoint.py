"""MAXScript ExecuteFile entrypoint for the Max 2026 embedded Python."""

from __future__ import annotations

import os
import sys


def main() -> None:
    package_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    if package_root not in sys.path:
        sys.path.insert(0, package_root)
    from pymxs import runtime as rt

    try:
        page = str(rt.AmenoPythonUIRequestedPage or "login")
    except Exception:
        page = "login"
    import ameno_ui

    ameno_ui.show(page)


if __name__ == "__main__":
    main()
