"""Run the repository's dependency-free Python test functions."""

from __future__ import annotations

import importlib.util
import os
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")


def main() -> None:
    files = sorted((ROOT / "tests" / "python").glob("test_*.py"))
    executed = 0
    for path in files:
        spec = importlib.util.spec_from_file_location(path.stem, path)
        if spec is None or spec.loader is None:
            raise RuntimeError("Não foi possível carregar %s" % path)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        for name in sorted(item for item in dir(module) if item.startswith("test_")):
            print("RUN %s::%s" % (path.name, name))
            getattr(module, name)()
            executed += 1
    print("PASS: %d testes Python" % executed)


if __name__ == "__main__":
    main()
