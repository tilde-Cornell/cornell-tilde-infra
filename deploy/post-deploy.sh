#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

require_root

section "tilde@Cornell post-deploy"

"$SCRIPT_DIR/apply-runtime.sh"

section "Post-deploy complete"
