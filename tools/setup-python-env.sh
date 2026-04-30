#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
venv_path="${1:-$repo_root/.venv}"
python_bin="${PYTHON_BIN:-python3}"

"$python_bin" -m venv "$venv_path"

site_packages="$("$venv_path/bin/python" - <<'PY'
import sysconfig

print(sysconfig.get_paths()["purelib"])
PY
)"

printf '%s\n' "$repo_root/opt/cornell-tilde/lib" > "$site_packages/cornell-tilde-infra.pth"

cat <<EOF
Python environment ready:
  $venv_path

Point your IDE at:
  $venv_path/bin/python

For local runs, set:
  BASE_DIR=$repo_root/opt/cornell-tilde
  WEB_ROOT=$repo_root/var/www/html
EOF
