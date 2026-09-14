#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/lib.sh"

family="$(os_family)"

case "$family" in
Archlinux)
    sudo pacman -S --noconfirm --needed base-devel git
    if ! command -v yay >/dev/null; then
        tmp_yay="$(mktemp -d)"
        git clone https://aur.archlinux.org/yay.git "$tmp_yay"
        (cd "$tmp_yay" && makepkg -si --noconfirm)
        rm -rf "$tmp_yay"
    fi
    yay -S --noconfirm --needed \
        google-chrome texlive-basic texlive-latexextra texlive-fontsrecommended \
        visual-studio-code-bin discord github-cli sl fastfetch btop gti cowsay \
        wl-clipboard aws-cli-bin
    ;;
Debian)
    sudo install -d -m 0755 /etc/apt/keyrings
    sudo curl -fsSL https://dl.google.com/linux/linux_signing_key.pub -o /etc/apt/keyrings/google.asc
    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/google.asc] https://dl.google.com/linux/chrome/deb/ stable main" \
        | sudo tee /etc/apt/sources.list.d/google-chrome.list >/dev/null
    sudo curl -fsSL https://packages.microsoft.com/keys/microsoft.asc -o /etc/apt/keyrings/microsoft.asc
    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/microsoft.asc] https://packages.microsoft.com/repos/code stable main" \
        | sudo tee /etc/apt/sources.list.d/vscode.list >/dev/null
    sudo apt-get update
    sudo apt-get install -y google-chrome-stable code gh sl fastfetch btop gti cowsay wl-clipboard awscli
    if ! dpkg -s discord >/dev/null 2>&1; then
        curl -fsSL "https://discord.com/api/download?platform=linux&format=deb" -o /tmp/discord.deb
        sudo apt-get install -y /tmp/discord.deb
    fi
    ;;
RedHat)
    sudo tee /etc/yum.repos.d/google-chrome.repo >/dev/null <<'EOF'
[google-chrome]
name=Google Chrome
baseurl=https://dl.google.com/linux/chrome/rpm/stable/x86_64
enabled=1
gpgcheck=1
gpgkey=https://dl.google.com/linux/linux_signing_key.pub
EOF
    sudo tee /etc/yum.repos.d/vscode.repo >/dev/null <<'EOF'
[vscode]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF
    sudo tee /etc/yum.repos.d/gh-cli.repo >/dev/null <<'EOF'
[gh-cli]
name=packages for the GitHub CLI
baseurl=https://cli.github.com/packages/rpm
enabled=1
gpgcheck=1
gpgkey=https://cli.github.com/packages/githubcli-archive-keyring.asc
EOF
    sudo dnf install -y google-chrome-stable texlive-scheme-full code gh sl fastfetch btop gti cowsay wl-clipboard awscli2
    if ! rpm -q discord >/dev/null 2>&1; then
        curl -fsSL "https://discord.com/api/download?platform=linux&format=rpm" -o /tmp/discord.rpm
        sudo dnf install -y --nogpgcheck /tmp/discord.rpm
    fi
    ;;
Darwin)
    brew install --cask google-chrome visual-studio-code zed discord wechat
    brew install gh sl fastfetch btop gti cowsay awscli
    ;;
esac

if [[ "$family" != "Darwin" ]]; then
    case "$family" in
        Archlinux) sudo pacman -S --noconfirm --needed flatpak ;;
        Debian)    sudo apt-get install -y flatpak ;;
        RedHat)    sudo dnf install -y flatpak ;;
    esac
    sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    sudo flatpak install -y flathub com.tencent.WeChat
fi
