#!/bin/bash
set -euo pipefail

config_path="/boot/firmware/config.txt"
block_marker="# pi_underclock"

if ! tr -d '\0' < /proc/device-tree/model 2>/dev/null | grep -q "Raspberry Pi 5"; then
    echo "pi_underclock.sh only applies to a Raspberry Pi 5" >&2
    exit 1
fi
if [[ ! -f "$config_path" ]]; then
    echo "$config_path not found" >&2
    exit 1
fi

mode="${1:-apply}"
if [[ "$mode" != "apply" && "$mode" != "revert" ]]; then
    echo "usage: $0 [apply|revert]" >&2
    exit 1
fi

sudo cp "$config_path" "$config_path.bak.$(date +%s)"
sudo sed -i -e "/^$block_marker\$/,+3d" -e '/^arm_freq=/d' -e '/^over_voltage_delta=/d' "$config_path"

if [[ "$mode" == "apply" ]]; then
    # [all] so the settings are not swallowed by a trailing [pi4]/[cm5] filter section
    printf '%s\n[all]\narm_freq=1000\nover_voltage_delta=-50000\n' "$block_marker" | sudo tee -a "$config_path" >/dev/null
fi

echo "$mode done, reboot to take effect"
