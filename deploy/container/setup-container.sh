#! /bin/bash
set -euo pipefail

if [ ! -f "/deploy/container/systemd/done" ]; then
    set -a
    source /deploy/container/systemd/setup-container.env
    /bin/bash /deploy/setup.sh
    rm -f /deploy/container/systemd/setup-container.env
    set +a
fi
