#!/bin/bash
set -euo pipefail

if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "deploy_nvidia_sleep.sh is not applicable on macOS" >&2
    exit 0
fi

src_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../nvidia" && pwd)"

# same basename as the packaged file in /usr/lib/modprobe.d so this one shadows it
sudo install -Dm644 "$src_dir/nvidia-power-management.conf" /etc/modprobe.d/nvidia-power-management.conf
sudo restorecon -F /etc/modprobe.d/nvidia-power-management.conf
sudo systemctl enable nvidia-suspend.service nvidia-resume.service nvidia-hibernate.service

echo "reboot to reload the nvidia module, then check: grep -E 'UseKernelSuspendNotifiers|PreserveVideoMemoryAllocations' /proc/driver/nvidia/params"
