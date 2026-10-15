#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
dotfiles_dir="$(dirname "$script_dir")"
source "$script_dir/lib.sh"

user_home="$HOME"

ensure_dir "$user_home/.claude"
for f in "$dotfiles_dir"/claude/*; do
    symlink "$f" "$user_home/.claude/$(basename "$f")"
done
