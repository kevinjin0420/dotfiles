#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/lib.sh"

[[ "$(id -u)" -ne 0 ]] || { echo "Do not run as root" >&2; exit 1; }

family="$(os_family)"
case "$family" in
    Archlinux|RedHat) ;;
    *) echo "envycontrol setup only covers Fedora and Arch -- Debian/Ubuntu already ship prime-select" >&2; exit 1 ;;
esac

if [[ "$family" == "Archlinux" ]]; then
    command -v yay >/dev/null || { echo "yay not found -- run setup/software.sh first to bootstrap the AUR helper" >&2; exit 1; }
fi

if [[ "$family" == "RedHat" ]]; then
    sudo dnf copr enable -y sunwire/envycontrol
    sudo dnf install -y python3-envycontrol
elif [[ "$family" == "Archlinux" ]]; then
    yay -S --noconfirm --needed envycontrol
fi

if command -v kwriteconfig6 >/dev/null; then
    if [[ "$family" == "Archlinux" ]]; then
        yay -S --noconfirm --needed plasma6-applets-optimus-gpu-switcher-git
    elif [[ "$family" == "RedHat" ]]; then
        # no fedora package available, github releases ships plasma 5 widget, cant use
        tmp="$(mktemp -d)"
        curl -fsSL https://github.com/enielrodriguez/optimus-gpu-switcher/archive/refs/heads/main.tar.gz \
            | tar -xz -C "$tmp" --strip-components=1
        kpackagetool6 --type Plasma/Applet --install "$tmp" 2>/dev/null \
            || kpackagetool6 --type Plasma/Applet --upgrade "$tmp"
        rm -rf "$tmp"
    fi
fi
