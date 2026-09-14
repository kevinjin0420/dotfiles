#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
dotfiles_dir="$(dirname "$script_dir")"
source "$script_dir/lib.sh"

user_home="$HOME"
family="$(os_family)"

case "$family" in
Debian)
    sudo apt-get update
    sudo apt-get install -y fcitx5 fcitx5-rime fcitx5-chinese-addons librime1 \
        rime-data-luna-pinyin rime-essay rime-prelude
    dpkg -s libqt5core5a >/dev/null 2>&1 && sudo apt-get install -y fcitx5-frontend-qt5
    dpkg -s libqt6core6 >/dev/null 2>&1 && sudo apt-get install -y fcitx5-frontend-qt6
    dpkg -s libgtk-3-0 >/dev/null 2>&1 && sudo apt-get install -y fcitx5-frontend-gtk3
    dpkg -s libgtk-4-1 >/dev/null 2>&1 && sudo apt-get install -y fcitx5-frontend-gtk4
    ;;
Archlinux)
    sudo pacman -S --noconfirm --needed fcitx5 fcitx5-rime fcitx5-chinese-addons rime-luna-pinyin
    (pacman -Qq qt5-base 2>/dev/null || pacman -Qq qt6-base 2>/dev/null) \
        && sudo pacman -S --noconfirm --needed fcitx5-qt
    (pacman -Qq gtk3 2>/dev/null || pacman -Qq gtk4 2>/dev/null) \
        && sudo pacman -S --noconfirm --needed fcitx5-gtk
    ;;
RedHat)
    sudo dnf install -y fcitx5 fcitx5-rime fcitx5-chinese-addons
    (rpm -q qt5-qtbase >/dev/null 2>&1 || rpm -q qt6-qtbase >/dev/null 2>&1) \
        && sudo dnf install -y fcitx5-qt
    rpm -q gtk3 >/dev/null 2>&1 && sudo dnf install -y fcitx5-gtk3
    rpm -q gtk4 >/dev/null 2>&1 && sudo dnf install -y fcitx5-gtk4
    ;;
esac

if [[ "$family" != "Darwin" ]]; then
    ensure_dir "$user_home/.config/fcitx5/conf" "$user_home/.local/share/fcitx5/rime" "$user_home/.config/environment.d"

    cp "$dotfiles_dir/config/fcitx5/config" "$user_home/.config/fcitx5/config"
    cp "$dotfiles_dir/config/fcitx5/profile" "$user_home/.config/fcitx5/profile"
    cp "$dotfiles_dir/config/fcitx5/conf/rime.conf" "$user_home/.config/fcitx5/conf/rime.conf"
    cp "$dotfiles_dir/local/share/fcitx5/rime/default.custom.yaml" "$user_home/.local/share/fcitx5/rime/default.custom.yaml"
    chmod 0644 "$user_home/.config/fcitx5/config" "$user_home/.config/fcitx5/profile" \
        "$user_home/.config/fcitx5/conf/rime.conf" "$user_home/.local/share/fcitx5/rime/default.custom.yaml"

    if [[ ! -e "$user_home/.local/share/fcitx5/rime/luna_pinyin.userdb" ]]; then
        cp -r "$dotfiles_dir/local/share/fcitx5/rime/luna_pinyin.userdb" \
            "$user_home/.local/share/fcitx5/rime/luna_pinyin.userdb"
    fi

    cp "$dotfiles_dir/config/environment.d/fcitx5.conf" "$user_home/.config/environment.d/fcitx5.conf"
    chmod 0644 "$user_home/.config/environment.d/fcitx5.conf"

    if [[ "${XDG_CURRENT_DESKTOP:-}" == "KDE" ]]; then
        kwriteconfig6 --file kwinrc --group Wayland --key InputMethod \
            /usr/share/applications/fcitx5-wayland-launcher.desktop
        kwriteconfig6 --file kglobalshortcutsrc --group "KDE Keyboard Layout Switcher" \
            --key "Switch to Next Keyboard Layout" "none,Meta+Alt+K,Switch to Next Keyboard Layout"
    fi

    if [[ ! -e "$user_home/.xprofile" ]]; then
        cat > "$user_home/.xprofile" <<'EOF'
export GTK_IM_MODULE=fcitx
export QT_IM_MODULE=fcitx
export XMODIFIERS=@im=fcitx
EOF
        chmod 0644 "$user_home/.xprofile"
    fi
fi
