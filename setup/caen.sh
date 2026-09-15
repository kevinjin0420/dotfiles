#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
dotfiles_dir="$(dirname "$script_dir")"
source "$script_dir/lib.sh"

user_home="$HOME"
local_prefix="$user_home/.local"
neovim_release="stable"
neovim_dir="nvim-linux-x86_64"

for tool in zsh git curl tar; do
    command -v "$tool" >/dev/null || { echo "missing required tool: $tool" >&2; exit 1; }
done

ensure_dir "$local_prefix/bin" "$local_prefix/opt" "$user_home/.config/tmux"

if [[ ! -x "$local_prefix/opt/$neovim_dir/bin/nvim" ]]; then
    curl -fsSL "https://github.com/neovim/neovim/releases/download/$neovim_release/$neovim_dir.tar.gz" \
        | tar -xz -C "$local_prefix/opt"
fi
symlink "$local_prefix/opt/$neovim_dir/bin/nvim" "$local_prefix/bin/nvim"

clone_shallow https://github.com/junegunn/fzf "$user_home/.fzf"
[[ -x "$user_home/.fzf/bin/fzf" ]] || "$user_home/.fzf/install" --bin
symlink "$user_home/.fzf/bin/fzf" "$local_prefix/bin/fzf"

setup_zsh_omz "$user_home"

backup_suffix=".bak.$(date +%s)"
for f in .bash_profile .bashrc .zshrc .p10k.zsh .gitconfig always-forget.md; do
    path="$user_home/$f"
    if [[ -e "$path" && ! -L "$path" ]]; then
        mv "$path" "$path$backup_suffix"
    fi
done
if [[ -d "$user_home/.config/nvim" && ! -L "$user_home/.config/nvim" ]]; then
    mv "$user_home/.config/nvim" "$user_home/.config/nvim$backup_suffix"
fi

declare -A dotfile_links=(
    ["dots/zshrc"]=".zshrc"
    ["dots/p10k.zsh"]=".p10k.zsh"
    ["dots/gitconfig"]=".gitconfig"
    ["dots/always_forget.md"]="always-forget.md"
    ["dots/bash_profile"]=".bash_profile"
    ["dots/bash_profile"]=".bashrc"
    ["dots/clang-format"]=".clang-format"
    ["config/tmux/tmux.conf"]=".config/tmux/tmux.conf"
    ["config/nvim"]=".config/nvim"
)
for src in "${!dotfile_links[@]}"; do
    symlink "$dotfiles_dir/$src" "$user_home/${dotfile_links[$src]}"
done

cat <<EOF
nvim $neovim_release installed to ~/.local/opt/$neovim_dir; ~/.local/bin is added to PATH by zshrc.
Login shell stays bash; ~/.bash_profile execs zsh on interactive sessions.
Run nvim once to let LazyVim sync plugins. Watch AFS quota: fs listquota ~
eecs482 setup is separate: ./setup/eecs482.sh
EOF
