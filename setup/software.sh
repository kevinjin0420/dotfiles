#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/lib.sh"

family="$(os_family)"

declare -A DESC=(
    [chrome]="Google Chrome"
    [vscode]="Visual Studio Code"
    [discord]="Discord"
    [slack]="Slack"
    [spotify]="Spotify"
    [texlive]="LaTeX (texlive)"
    [wechat]="WeChat"
)
options=(chrome vscode discord slack spotify)
case "$family" in
    Archlinux|RedHat) options+=(texlive) ;;
esac
options+=(wechat)
if [[ "$family" == "Darwin" ]]; then
    DESC[zed]="Zed"
    options+=(zed)
fi

declare -A INSTALL
echo "Select software to install (Enter = yes):"
for key in "${options[@]}"; do
    read -rp "  Install ${DESC[$key]}? [Y/n] " ans
    case "$ans" in
        [nN]*) INSTALL[$key]=0 ;;
        *) INSTALL[$key]=1 ;;
    esac
done

want() { [[ "${INSTALL[$1]:-0}" == 1 ]]; }

case "$family" in
Archlinux)
    sudo pacman -S --noconfirm --needed base-devel git
    if ! command -v yay >/dev/null; then
        tmp_yay="$(mktemp -d)"
        git clone https://aur.archlinux.org/yay.git "$tmp_yay"
        (cd "$tmp_yay" && makepkg -si --noconfirm)
        rm -rf "$tmp_yay"
    fi
    pkgs=(github-cli sl fastfetch btop gti cowsay wl-clipboard aws-cli-bin)
    want chrome && pkgs+=(google-chrome)
    want texlive && pkgs+=(texlive-basic texlive-latexextra texlive-fontsrecommended)
    want vscode && pkgs+=(visual-studio-code-bin)
    want discord && pkgs+=(discord)
    want slack && pkgs+=(slack-desktop)
    want spotify && pkgs+=(spotify)
    yay -S --noconfirm --needed "${pkgs[@]}"
    ;;
Debian)
    pkgs=(gh sl fastfetch btop gti cowsay wl-clipboard awscli)
    if want chrome; then
        sudo install -d -m 0755 /etc/apt/keyrings
        sudo curl -fsSL https://dl.google.com/linux/linux_signing_key.pub -o /etc/apt/keyrings/google.asc
        echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/google.asc] https://dl.google.com/linux/chrome/deb/ stable main" \
            | sudo tee /etc/apt/sources.list.d/google-chrome.list >/dev/null
        pkgs+=(google-chrome-stable)
    fi
    if want vscode; then
        sudo install -d -m 0755 /etc/apt/keyrings
        sudo curl -fsSL https://packages.microsoft.com/keys/microsoft.asc -o /etc/apt/keyrings/microsoft.asc
        echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/microsoft.asc] https://packages.microsoft.com/repos/code stable main" \
            | sudo tee /etc/apt/sources.list.d/vscode.list >/dev/null
        pkgs+=(code)
    fi
    sudo apt-get update
    sudo apt-get install -y "${pkgs[@]}"
    if want discord && ! dpkg -s discord >/dev/null 2>&1; then
        curl -fsSL "https://discord.com/api/download?platform=linux&format=deb" -o /tmp/discord.deb
        sudo apt-get install -y /tmp/discord.deb
    fi
    ;;
RedHat)
    if want chrome; then
        sudo tee /etc/yum.repos.d/google-chrome.repo >/dev/null <<'EOF'
[google-chrome]
name=Google Chrome
baseurl=https://dl.google.com/linux/chrome/rpm/stable/x86_64
enabled=1
gpgcheck=1
gpgkey=https://dl.google.com/linux/linux_signing_key.pub
EOF
    fi
    if want vscode; then
        sudo tee /etc/yum.repos.d/vscode.repo >/dev/null <<'EOF'
[vscode]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF
    fi
    sudo tee /etc/yum.repos.d/gh-cli.repo >/dev/null <<'EOF'
[gh-cli]
name=packages for the GitHub CLI
baseurl=https://cli.github.com/packages/rpm
enabled=1
gpgcheck=1
gpgkey=https://cli.github.com/packages/githubcli-archive-keyring.asc
EOF
    pkgs=(gh sl fastfetch btop gti cowsay wl-clipboard awscli2)
    want chrome && pkgs+=(google-chrome-stable)
    want vscode && pkgs+=(code)
    want texlive && pkgs+=(texlive-scheme-full)
    sudo dnf install -y "${pkgs[@]}"
    if want discord && ! rpm -q discord >/dev/null 2>&1; then
        curl -fsSL "https://discord.com/api/download?platform=linux&format=rpm" -o /tmp/discord.rpm
        sudo dnf install -y --nogpgcheck /tmp/discord.rpm
    fi
    ;;
Darwin)
    casks=()
    want chrome && casks+=(google-chrome)
    want vscode && casks+=(visual-studio-code)
    want zed && casks+=(zed)
    want discord && casks+=(discord)
    want slack && casks+=(slack)
    want spotify && casks+=(spotify)
    want wechat && casks+=(wechat)
    [[ ${#casks[@]} -eq 0 ]] || brew install --cask "${casks[@]}"
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
    flatpak_apps=()
    want wechat && flatpak_apps+=(com.tencent.WeChat)
    if [[ "$family" != "Archlinux" ]]; then
        want slack && flatpak_apps+=(com.slack.Slack)
        want spotify && flatpak_apps+=(com.spotify.Client)
    fi
    [[ ${#flatpak_apps[@]} -eq 0 ]] || sudo flatpak install -y flathub "${flatpak_apps[@]}"
fi
