#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
dotfiles_dir="$(dirname "$script_dir")"
source "$script_dir/lib.sh"

user_home="$HOME"
local_prefix="$user_home/.local"

case "$(uname -m)" in
    aarch64|arm64) neovim_arch="arm64"; tree_sitter_arch="arm64" ;;
    x86_64)        neovim_arch="x86_64"; tree_sitter_arch="x64" ;;
    *) echo "unsupported arch $(uname -m): neovim ships no 32-bit builds" >&2; exit 1 ;;
esac
# 32-bit Pi OS can run on a 64-bit kernel and still report aarch64
if [[ "$(getconf LONG_BIT)" != "64" ]]; then
    echo "32-bit userland detected: neovim ships no 32-bit builds, install 64-bit Pi OS" >&2
    exit 1
fi
neovim_dir="nvim-linux-$neovim_arch"

case "$(os_family)" in
    Debian)    sudo apt-get update && sudo apt-get install -y zsh fzf git curl tar gzip python3 python3-venv tmux build-essential unzip ripgrep fd-find nodejs npm cowsay sl ;;
    Archlinux) sudo pacman -Sy --noconfirm --needed zsh fzf git curl tar gzip python tmux base-devel unzip ripgrep fd nodejs npm cowsay sl ;;
    RedHat)    sudo dnf install -y zsh fzf git curl tar gzip python3 tmux gcc make unzip ripgrep fd-find nodejs npm cowsay sl ;;
esac

zsh_path="$(which zsh)"
grep -qxF "$zsh_path" /etc/shells || echo "$zsh_path" | sudo tee -a /etc/shells >/dev/null
sudo chsh -s "$zsh_path" "$USER"

setup_zsh_omz "$user_home"

ensure_dir "$local_prefix/bin" "$local_prefix/opt" "$user_home/.config/tmux"

neovim_tmp="$(mktemp -d)"
trap 'rm -rf "$neovim_tmp"' EXIT
curl -fsSL "https://github.com/neovim/neovim/releases/latest/download/$neovim_dir.tar.gz" \
    | tar -xz -C "$neovim_tmp"
rm -rf "$local_prefix/opt/$neovim_dir"
mv "$neovim_tmp/$neovim_dir" "$local_prefix/opt/$neovim_dir"
symlink "$local_prefix/opt/$neovim_dir/bin/nvim" "$local_prefix/bin/nvim"

# nvim-treesitter main branch compiles parsers with the tree-sitter CLI, which distro repos ship too old
curl -fsSL "https://github.com/tree-sitter/tree-sitter/releases/latest/download/tree-sitter-linux-$tree_sitter_arch.gz" \
    | gunzip > "$local_prefix/bin/tree-sitter"
chmod +x "$local_prefix/bin/tree-sitter"

if [[ -e "$user_home/.config/nvim" && ! -L "$user_home/.config/nvim" ]]; then
    mv "$user_home/.config/nvim" "$user_home/.config/nvim.bak.$(date +%s)"
fi

declare -A dotfile_links=(
    ["dots/zshrc"]=".zshrc"
    ["dots/p10k.zsh"]=".p10k.zsh"
    ["dots/gitconfig"]=".gitconfig"
    ["dots/always_forget.md"]="always-forget.md"
    ["dots/clang-format"]=".clang-format"
    ["config/tmux/tmux.conf"]=".config/tmux/tmux.conf"
    ["config/nvim"]=".config/nvim"
)
for src in "${!dotfile_links[@]}"; do
    symlink "$dotfiles_dir/$src" "$user_home/${dotfile_links[$src]}"
done

PATH="$local_prefix/bin:$PATH" "$local_prefix/bin/nvim" --headless "+Lazy! restore" +qa

echo "nvim $("$local_prefix/bin/nvim" --version | head -n1) installed; plugins restored from lazy-lock.json"
