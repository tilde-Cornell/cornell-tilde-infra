#!/bin/bash
set -euo pipefail

source /deploy/common.sh
SCRIPT_DIR="$(deploy_script_dir)"

require_root

section "tilde@Cornell post-deploy"

"$SCRIPT_DIR/apply-runtime.sh"

section "Post-deploy complete"
