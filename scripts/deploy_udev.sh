#!/bin/bash
set -euo pipefail

if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "deploy_udev.sh is not applicable on macOS" >&2
    exit 0
fi

rules_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../udev/rules.d" && pwd)"

for rule in "$rules_dir"/*.rules; do
    sudo ln -sf "$rule" "/etc/udev/rules.d/$(basename "$rule")"
done

sudo udevadm control --reload-rules
sudo udevadm trigger
