#!/usr/bin/env bash
# Shared helpers for setup/*.sh. Source this, don't execute it directly.

os_family() {
    if [[ "${OSTYPE:-}" == darwin* ]]; then
        echo "Darwin"
        return
    fi
    if [[ -r /etc/os-release ]]; then
        # shellcheck source=/dev/null
        . /etc/os-release
        case "${ID:-} ${ID_LIKE:-}" in
            *arch*) echo "Archlinux"; return ;;
            *debian*|*ubuntu*) echo "Debian"; return ;;
            *rhel*|*fedora*) echo "RedHat"; return ;;
        esac
    fi
    echo "Unrecognized OS family (ID=${ID:-unset} ID_LIKE=${ID_LIKE:-unset})" >&2
    exit 1
}

ensure_dir() {
    for dir in "$@"; do
        mkdir -p "$dir"
    done
}

symlink() {
    local src="$1" dest="$2"
    mkdir -p "$(dirname "$dest")"
    ln -sf "$src" "$dest"
}

clone_shallow() {
    local repo="$1" dest="$2"
    [[ -d "$dest" ]] || git clone --depth 1 "$repo" "$dest"
}

setup_zsh_omz() {
    local user_home="$1"
    local zsh_custom="$user_home/.oh-my-zsh/custom"

    if [[ ! -d "$user_home/.oh-my-zsh" ]]; then
        git clone --depth 1 https://github.com/ohmyzsh/ohmyzsh.git "$user_home/.oh-my-zsh"
    fi

    clone_shallow https://github.com/zsh-users/zsh-autosuggestions "$zsh_custom/plugins/zsh-autosuggestions"
    clone_shallow https://github.com/zsh-users/zsh-syntax-highlighting "$zsh_custom/plugins/zsh-syntax-highlighting"
    clone_shallow https://github.com/romkatv/powerlevel10k "$zsh_custom/themes/powerlevel10k"
}
