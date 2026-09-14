#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
dotfiles_dir="$(dirname "$script_dir")"
source "$script_dir/lib.sh"

user_home="$HOME"
family="$(os_family)"

case "$family" in
    Archlinux) sudo pacman -Sy --noconfirm --needed zsh fzf git git-delta curl neovim python3 cowsay sl ;;
    Debian)    sudo apt-get update && sudo apt-get install -y zsh fzf git git-delta curl neovim python3 cowsay sl ;;
    RedHat)    sudo dnf install -y zsh fzf git git-delta curl neovim python3 cowsay sl ;;
    Darwin)    brew install zsh fzf git git-delta curl neovim python3 cowsay sl ;;
esac

zsh_path="$(which zsh)"
grep -qxF "$zsh_path" /etc/shells || echo "$zsh_path" | sudo tee -a /etc/shells >/dev/null
sudo chsh -s "$zsh_path" "$USER"

setup_zsh_omz "$user_home"

if [[ "$family" == "Darwin" ]]; then
    kitty_install_dir="$user_home/Applications"
    kitty_bin_dir="$kitty_install_dir/kitty.app/Contents/MacOS"
else
    kitty_install_dir="$user_home/.local"
    kitty_bin_dir="$kitty_install_dir/kitty.app/bin"
fi
kitty_app_dir="$kitty_install_dir/kitty.app"

kitty_latest="$(curl -fsSL https://api.github.com/repos/kovidgoyal/kitty/releases/latest \
    | grep -m1 '"tag_name"' | sed -E 's/.*"v?([^"]+)".*/\1/')"
kitty_installed="$("$kitty_bin_dir/kitty" --version 2>/dev/null | awk '{print $2}' || true)"
if [[ "$kitty_installed" != "$kitty_latest" ]]; then
    curl -L https://sw.kovidgoyal.net/kitty/installer.sh | sh /dev/stdin dest="$kitty_install_dir" launch=n
fi

ensure_dir "$user_home/.local/bin"
symlink "$kitty_bin_dir/kitty" "$user_home/.local/bin/kitty"
symlink "$kitty_bin_dir/kitten" "$user_home/.local/bin/kitten"
symlink "$dotfiles_dir/scripts/git-set-author" "$user_home/.local/bin/git-set-author"

ensure_dir \
    "$user_home/.config/kitty" \
    "$user_home/.config/tmux" \
    "$user_home/.config/fastfetch" \
    "$user_home/.config/zed" \
    "$user_home/Documents/wallpapers"

for f in "$dotfiles_dir"/wallpapers/*; do
    dest="$user_home/Documents/wallpapers/$(basename "$f")"
    [[ -e "$dest" ]] || cp "$f" "$dest"
done

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

if [[ -e "$user_home/.config/nvim" && ! -L "$user_home/.config/nvim" ]]; then
    rm -rf "$user_home/.config/nvim"
fi
symlink "$dotfiles_dir/config/nvim" "$user_home/.config/nvim"

if [[ "$family" == "Darwin" ]]; then
    cp "$dotfiles_dir"/fonts/*.ttf "$user_home/Library/Fonts/"
else
    sudo cp "$dotfiles_dir"/fonts/*.ttf /usr/share/fonts/
    sudo fc-cache -f
fi

declare -A dotfile_links=(
    ["dots/zshrc"]=".zshrc"
    ["dots/p10k.zsh"]=".p10k.zsh"
    ["dots/gitconfig"]=".gitconfig"
    ["dots/always_forget.md"]="always-forget.md"
    ["dots/clang-format"]=".clang-format"
    ["config/kitty/kitty.conf"]=".config/kitty/kitty.conf"
    ["config/tmux/tmux.conf"]=".config/tmux/tmux.conf"
    ["config/fastfetch/config.jsonc"]=".config/fastfetch/config.jsonc"
    ["config/fastfetch/kuromi.txt"]=".config/fastfetch/kuromi.txt"
    ["config/zed/settings.json"]=".config/zed/settings.json"
)
for src in "${!dotfile_links[@]}"; do
    symlink "$dotfiles_dir/$src" "$user_home/${dotfile_links[$src]}"
done

if [[ "$family" != "Darwin" ]]; then
    sudo "$dotfiles_dir/scripts/deploy_udev.sh"
fi
