#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/lib.sh"

[[ "$(os_family)" == RedHat ]] || { echo "purge list targets the Fedora KDE spin only" >&2; exit 1; }

unwanted_packages=(
    kmines kpat
    kmail kontact korganizer kaddressbook ktnef akonadi-server kleopatra kio-gdrive
    kamoso kmouth qrca neochat krdc krfb elisa-player kolourpaint skanpage
    plasma-welcome mediawriter
)

installed_unwanted=()
for package in "${unwanted_packages[@]}"; do
    rpm -q "$package" >/dev/null 2>&1 && installed_unwanted+=("$package")
done

if (( ${#installed_unwanted[@]} == 0 )); then
    echo "nothing to purge"
    exit 0
fi

sudo dnf remove -y "${installed_unwanted[@]}"
sudo dnf autoremove -y
