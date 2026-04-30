#!/usr/bin/env python3
import site
import sys
from pathlib import Path


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: install-python-path.py PROJECT_ROOT", file=sys.stderr)
        return 2

    project_root = Path(sys.argv[1]).resolve()
    lib_path = project_root / "lib"

    site_packages = Path(site.getsitepackages()[0])
    site_packages.mkdir(parents=True, exist_ok=True)

    pth_path = site_packages / "cornell-tilde-infra.pth"
    pth_path.write_text(f"{lib_path}\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
