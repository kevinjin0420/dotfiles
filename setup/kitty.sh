#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
dotfiles_dir="$(dirname "$script_dir")"
source "$script_dir/lib.sh"

user_home="$HOME"
family="$(os_family)"

if [[ "$family" == "Darwin" ]]; then
    kitty_install_dir="$user_home/Applications"
    kitty_bin_dir="$kitty_install_dir/kitty.app/Contents/MacOS"
else
    kitty_install_dir="$user_home/.local"
    kitty_bin_dir="$kitty_install_dir/kitty.app/bin"
fi
kitty_app_dir="$kitty_install_dir/kitty.app"

kitty_release_json="$(curl -fsSL https://api.github.com/repos/kovidgoyal/kitty/releases/latest)"
kitty_latest="$(printf '%s' "$kitty_release_json" \
    | grep '"tag_name"' | sed -E 's/.*"v?([^"]+)".*/\1/')"
kitty_installed="$("$kitty_bin_dir/kitty" --version 2>/dev/null | awk '{print $2}' || true)"
if [[ "$kitty_installed" != "$kitty_latest" ]]; then
    curl -L https://sw.kovidgoyal.net/kitty/installer.sh | sh /dev/stdin dest="$kitty_install_dir" launch=n
fi

symlink "$kitty_bin_dir/kitty" "$user_home/.local/bin/kitty"
symlink "$kitty_bin_dir/kitten" "$user_home/.local/bin/kitten"
symlink "$dotfiles_dir/config/kitty/kitty.conf" "$user_home/.config/kitty/kitty.conf"

if [[ "$family" != "Darwin" ]]; then
    ensure_dir "$user_home/.local/share/applications"
    for desktop in kitty.desktop kitty-open.desktop; do
        dest="$user_home/.local/share/applications/$desktop"
        [[ -e "$dest" ]] || cp "$kitty_app_dir/share/applications/$desktop" "$dest"
        sed -i \
            -e "s#^Icon=kitty\$#Icon=$kitty_app_dir/share/icons/hicolor/256x256/apps/kitty.png#" \
            -e "s#^Exec=kitty#Exec=$kitty_bin_dir/kitty#" \
            -e "s#^TryExec=.*#TryExec=$kitty_bin_dir/kitty#" \
            "$dest"
    done
    sed -i '/^Categories=/a X-KDE-Shortcuts=Alt+Return' "$user_home/.local/share/applications/kitty.desktop"
    printf 'kitty.desktop\n' > "$user_home/.config/xdg-terminals.list"
    kbuildsycoca6 --noincremental 2>/dev/null || true
fi
