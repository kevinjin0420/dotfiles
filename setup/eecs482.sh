#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
dotfiles_dir="$(dirname "$script_dir")"
source "$script_dir/lib.sh"

user_home="$HOME"
version482_src="$dotfiles_dir/eecs482/version482.vim"

ensure_dir "$user_home/.vim/plugin" "$user_home/.local/share/nvim/site/plugin"
symlink "$version482_src" "$user_home/.vim/plugin/version482.vim"
symlink "$version482_src" "$user_home/.local/share/nvim/site/plugin/version482.vim"
