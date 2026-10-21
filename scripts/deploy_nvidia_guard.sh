#!/bin/bash
set -euo pipefail

if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "deploy_nvidia_guard.sh is not applicable on macOS" >&2
    exit 0
fi

src_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../nvidia" && pwd)"

# copied, not symlinked: SELinux denies systemd executing files labeled user_home_t
sudo install -Dm755 "$src_dir/akmods-nvidia-guard" /usr/local/sbin/akmods-nvidia-guard
sudo install -Dm644 "$src_dir/akmods-nvidia-guard.conf" /etc/systemd/system/akmods@.service.d/nvidia-guard.conf
sudo restorecon -F /usr/local/sbin/akmods-nvidia-guard /etc/systemd/system/akmods@.service.d/nvidia-guard.conf
sudo systemctl daemon-reload
