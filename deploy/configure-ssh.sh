#!/bin/bash
set -euo pipefail

source /deploy/common.sh
SCRIPT_DIR="$(deploy_script_dir)"

require_root

section "SSH configuration"

"$PYTHON_BIN" - <<'PY'
from pathlib import Path
import re

path = Path("/etc/ssh/sshd_config")
text = path.read_text()

managed_keys = {
    "PermitRootLogin": "no",
    "PasswordAuthentication": "no",
    "PermitUserEnvironment": "no",
}
managed_key_names = {key.lower() for key in managed_keys}

text = re.sub(
    r"(?ms)^# BEGIN CORNELL TILDE GLOBALS\n.*?^# END CORNELL TILDE GLOBALS\n?",
    "",
    text,
)
text = re.sub(
    r"(?ms)^# BEGIN CORNELL TILDE JOIN\n.*?^# END CORNELL TILDE JOIN\n?",
    "",
    text,
)

lines = text.splitlines()
without_old_join = []
inside_join_block = False

for line in lines:
    stripped = line.strip()

    if stripped == "Match User join":
        inside_join_block = True
        continue

    if inside_join_block:
        if stripped.startswith("Match "):
            inside_join_block = False
            without_old_join.append(line)
        else:
            continue
    else:
        without_old_join.append(line)

first_match = next(
    (index for index, line in enumerate(without_old_join) if line.strip().startswith("Match ")),
    len(without_old_join),
)

global_lines = without_old_join[:first_match]
match_lines = without_old_join[first_match:]

filtered_global = []

for line in global_lines:
    stripped = line.strip()
    parts = stripped.split()

    if stripped.startswith("#") or not parts:
        filtered_global.append(line)
        continue

    if parts[0].lower() in managed_key_names:
        continue

    filtered_global.append(line)

globals_block = [
    "# BEGIN CORNELL TILDE GLOBALS",
    "PermitRootLogin no",
    "PasswordAuthentication no",
    "PermitUserEnvironment no",
    "# END CORNELL TILDE GLOBALS",
]

first_include = next(
    (
        index
        for index, line in enumerate(filtered_global)
        if line.strip()
        and not line.strip().startswith("#")
        and line.strip().split()[0].lower() == "include"
    ),
    len(filtered_global),
)
filtered_global = (
    filtered_global[:first_include]
    + globals_block
    + filtered_global[first_include:]
)

join_block = """\
# BEGIN CORNELL TILDE JOIN
Match User join
        ForceCommand /opt/cornell-tilde/bin/join_script_wrapper.sh
        PasswordAuthentication yes
        PubkeyAuthentication no
        PermitTTY yes
        X11Forwarding no
        AllowTcpForwarding no
        AllowAgentForwarding no
        PermitTunnel no
""".splitlines()

dropin = Path("/etc/ssh/sshd_config.d/99-cornell-tilde-join.conf")
if dropin.exists():
    dropin.unlink()

output = filtered_global + match_lines + join_block
path.write_text("\n".join(output).rstrip() + "\n")
PY

sshd -t
systemctl restart ssh
