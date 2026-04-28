#!/bin/bash
set -euo pipefail

source /deploy/common.sh
SCRIPT_DIR="$(deploy_script_dir)"

require_root

section "SSH configuration"

python3 - <<'PY'
from pathlib import Path

path = Path("/etc/ssh/sshd_config")
text = path.read_text()

lines = text.splitlines()
new_lines = []
inside_join_block = False

for line in lines:
    stripped = line.strip()

    if stripped == "Match User join":
        inside_join_block = True
        continue

    if inside_join_block:
        if stripped.startswith("Match "):
            inside_join_block = False
            new_lines.append(line)
        else:
            continue
    else:
        new_lines.append(line)

first_match = next(
    (index for index, line in enumerate(new_lines) if line.strip().startswith("Match ")),
    len(new_lines),
)

global_lines = new_lines[:first_match]
match_lines = new_lines[first_match:]

managed_keys = {
    "PermitRootLogin": "no",
    "PasswordAuthentication": "no",
    "PermitUserEnvironment": "no",
}

filtered_global = []
include_seen = False

for line in global_lines:
    stripped = line.strip()
    parts = stripped.split()

    if stripped == "Include /etc/ssh/sshd_config.d/*.conf":
        include_seen = True

    if stripped.startswith("#") or not parts:
        filtered_global.append(line)
        continue

    if parts[0] in managed_keys:
        continue

    filtered_global.append(line)

if not include_seen:
    filtered_global.append("Include /etc/ssh/sshd_config.d/*.conf")

for key, value in managed_keys.items():
    filtered_global.append(f"{key} {value}")

path.write_text("\n".join(filtered_global + match_lines).rstrip() + "\n")

dropin_dir = Path("/etc/ssh/sshd_config.d")
dropin_dir.mkdir(parents=True, exist_ok=True)
dropin = dropin_dir / "99-cornell-tilde-join.conf"
dropin.write_text("""\
Match User join
        ForceCommand /opt/cornell-tilde/bin/join_script_wrapper.sh
        PasswordAuthentication yes
        PubkeyAuthentication no
        PermitTTY yes
        X11Forwarding no
        AllowTcpForwarding no
        AllowAgentForwarding no
        PermitTunnel no
""")
PY

sshd -t
systemctl restart ssh
