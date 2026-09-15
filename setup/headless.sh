#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
dotfiles_dir="$(dirname "$script_dir")"
source "$script_dir/lib.sh"

user_home="$HOME"

case "$(os_family)" in
    Debian)    sudo apt-get update && sudo apt-get install -y zsh fzf git curl neovim python3 cowsay sl tmux ;;
    Archlinux) sudo pacman -Sy --noconfirm --needed zsh fzf git curl neovim python3 cowsay sl tmux ;;
    RedHat)    sudo dnf install -y zsh fzf git curl neovim python3 cowsay sl tmux ;;
esac

zsh_path="$(which zsh)"
grep -qxF "$zsh_path" /etc/shells || echo "$zsh_path" | sudo tee -a /etc/shells >/dev/null
sudo chsh -s "$zsh_path" "$USER"

setup_zsh_omz "$user_home"

if [[ ! -d "$user_home/.config/nvim" ]]; then
    git clone https://github.com/LazyVim/starter "$user_home/.config/nvim"
fi

ensure_dir "$user_home/.config/tmux"

declare -A dotfile_links=(
    ["dots/zshrc"]=".zshrc"
    ["dots/p10k.zsh"]=".p10k.zsh"
    ["dots/gitconfig"]=".gitconfig"
    ["dots/always_forget.md"]="always-forget.md"
    ["dots/clang-format"]=".clang-format"
    ["config/tmux/tmux.conf"]=".config/tmux/tmux.conf"
)
for src in "${!dotfile_links[@]}"; do
    symlink "$dotfiles_dir/$src" "$user_home/${dotfile_links[$src]}"
done
