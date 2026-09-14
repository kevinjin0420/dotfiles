# Remove Ansible Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the `ansible/` playbook tree with plain, directly-runnable bash scripts under `setup/`, preserving behavior of all 9 current playbooks.

**Architecture:** One `setup/<name>.sh` per current `ansible/<name>.yml`, all sourcing a shared `setup/lib.sh`. No dispatcher wrapper — scripts are run directly (`./setup/local.sh`). Root steps call `sudo` inline at point of use; no upfront credential grab. No re-implemented idempotency machinery — rely on the underlying commands (`pacman -S`, `ln -sf`, `mkdir -p`, `git clone` guarded by `[ -d ... ]`) being safe to re-run.

**Tech Stack:** bash (`set -euo pipefail`), the distro package managers already in use (pacman/apt/dnf/brew), `sudo`, `kwriteconfig6`.

**Spec:** `docs/superpowers/specs/2026-09-13-remove-ansible-design.md`

## Global Constraints

- Every script: `#!/usr/bin/env bash` + `set -euo pipefail`, sources `setup/lib.sh`.
- No `--ask-become-pass` / upfront sudo. `sudo` is called inline only on the specific command that needs root.
- No Ansible-style change-tracking. Only keep an explicit pre-check where it prevents data loss (e.g. CAEN's "don't clobber a real dotfile that isn't already our symlink"), never merely to skip a naturally-idempotent command.
- `caen.sh` (and any script meant for CAEN) must never call `sudo`.
- Every script must pass `bash -n <script>` (syntax check) before being considered done.
- Verification: on this machine (Arch + KDE Plasma), actually run the script and confirm it completes without error and produces the same end state the corresponding playbook did (symlinks in place, packages installed, kwin settings applied). Branches for OSes not available here (Debian, RedHat, Darwin) are reviewed line-by-line against the source `.yml` for parity, not live-run.

---

### Task 1: Shared helper library

**Files:**
- Create: `setup/lib.sh`

**Interfaces:**
- Produces: `os_family` (echoes `Archlinux`/`Debian`/`RedHat`/`Darwin`, exits 1 with a stderr message otherwise), `ensure_dir DIR...`, `symlink SRC DEST`, `clone_shallow REPO DEST`, `setup_zsh_omz USER_HOME` — every later task sources this file and uses these exact names.

- [ ] **Step 1: Write `setup/lib.sh`**

```bash
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
```

- [ ] **Step 2: Syntax-check**

Run: `bash -n setup/lib.sh`
Expected: no output, exit 0.

- [ ] **Step 3: Functional check**

Run: `bash -c 'source setup/lib.sh; os_family'`
Expected: prints `Archlinux` on this machine.

- [ ] **Step 4: Commit**

```bash
git add setup/lib.sh
git commit -m "add shared shell helpers for setup scripts"
```

---

### Task 2: `setup/local.sh`

**Files:**
- Create: `setup/local.sh`
- Reference: `ansible/local.yml`, `ansible/tasks/local/*.yml`

**Interfaces:**
- Consumes: `os_family`, `ensure_dir`, `symlink`, `clone_shallow`, `setup_zsh_omz` from `setup/lib.sh` (Task 1).

- [ ] **Step 1: Write `setup/local.sh`**

```bash
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
```

- [ ] **Step 2: Syntax-check**

Run: `bash -n setup/local.sh`
Expected: no output, exit 0.

- [ ] **Step 3: Live run on this machine**

Run: `./setup/local.sh`
Expected: completes with exit 0; `~/.zshrc`, `~/.config/nvim`, `~/.local/bin/kitty` are symlinks pointing into the dotfiles repo; `zsh` is the login shell; oh-my-zsh and its 3 plugins/themes are present under `~/.oh-my-zsh`.

- [ ] **Step 4: Commit**

```bash
git add setup/local.sh
git commit -m "migrate local.yml to setup/local.sh"
```

---

### Task 3: `setup/software.sh`

**Files:**
- Create: `setup/software.sh`
- Reference: `ansible/software.yml` (if present), `ansible/tasks/software/*.yml`

**Interfaces:**
- Consumes: `os_family` from `setup/lib.sh`.

- [ ] **Step 1: Write `setup/software.sh`**

```bash
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
```

- [ ] **Step 2: Syntax-check**

Run: `bash -n setup/software.sh`
Expected: no output, exit 0.

- [ ] **Step 3: Review-only for untestable branches**

Diff the Debian/RedHat/Darwin case blocks against `ansible/tasks/software/{Debian,RedHat,Darwin}.yml` line by line; confirm every package name and repo URL carried over unchanged. Cannot live-run these on this machine.

- [ ] **Step 4: Live run on this machine (Archlinux branch)**

Run: `./setup/software.sh`
Expected: exit 0; `yay -S ...` completes; `which google-chrome-stable` (or the actual binary name) and `which code` succeed afterward.

- [ ] **Step 5: Commit**

```bash
git add setup/software.sh
git commit -m "migrate software.yml to setup/software.sh"
```

---

### Task 4: `setup/headless.sh` and `setup/caen.sh`

**Files:**
- Create: `setup/headless.sh`
- Create: `setup/caen.sh`
- Reference: `ansible/headless.yml`, `ansible/caen.yml`

**Interfaces:**
- Consumes: `os_family`, `ensure_dir`, `symlink`, `clone_shallow`, `setup_zsh_omz` from `setup/lib.sh`.

- [ ] **Step 1: Write `setup/headless.sh`**

```bash
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
    ["config/tmux/tmux.conf"]=".config/tmux/tmux.conf"
)
for src in "${!dotfile_links[@]}"; do
    symlink "$dotfiles_dir/$src" "$user_home/${dotfile_links[$src]}"
done
```

- [ ] **Step 2: Write `setup/caen.sh`**

```bash
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
```

- [ ] **Step 3: Syntax-check both**

Run: `bash -n setup/headless.sh && bash -n setup/caen.sh`
Expected: no output, exit 0.

- [ ] **Step 4: Review against source YAML**

Confirm `setup/caen.sh` calls `sudo` zero times (`grep -c sudo setup/caen.sh` → `0`), matching the no-sudo CAEN requirement. Compare each step against `ansible/caen.yml` and `ansible/headless.yml` for parity; neither is live-testable on this machine (this box isn't CAEN or headless).

- [ ] **Step 5: Commit**

```bash
git add setup/headless.sh setup/caen.sh
git commit -m "migrate headless.yml and caen.yml to setup/*.sh"
```

---

### Task 5: `setup/kde.sh`

**Files:**
- Create: `setup/kde.sh`
- Reference: `ansible/kde.yml`, `ansible/tasks/kde/*.yml`

**Interfaces:**
- Consumes: `os_family` from `setup/lib.sh`.

- [ ] **Step 1: Write `setup/kde.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
dotfiles_dir="$(dirname "$script_dir")"
source "$script_dir/lib.sh"

user_home="$HOME"
kitty_bin="$user_home/.local/kitty.app/bin/kitty"

[[ "$(id -u)" -ne 0 ]] || { echo "Do not run as root" >&2; exit 1; }
command -v kwriteconfig6 >/dev/null || { echo "kwriteconfig6 not found -- is KDE Plasma installed?" >&2; exit 1; }

klassy_installed() {
    find /usr /usr/local -name '*klassy*' -name '*.so' 2>/dev/null | grep -q .
}

if ! klassy_installed; then
    case "$(os_family)" in
        Archlinux)
            command -v yay >/dev/null || { echo "yay not found -- run setup/software.sh first" >&2; exit 1; }
            yay -S --noconfirm --needed klassy
            ;;
        RedHat)
            sudo dnf copr enable -y errornointernet/klassy
            sudo dnf install -y klassy
            ;;
        Debian)
            echo "klassy has no Debian/Ubuntu package. Build it from source following" >&2
            echo "https://github.com/paulmcauley/klassy/blob/master/INSTALL.md, then re-run this script." >&2
            exit 1
            ;;
    esac
    klassy_installed || { echo "klassy install appears to have failed" >&2; exit 1; }
fi

has_battery=false
ls /sys/class/power_supply/BAT* >/dev/null 2>&1 && has_battery=true

latest_asset_url() {
    local repo="$1" asset_name="$2"
    curl -fsSL "https://api.github.com/repos/$repo/releases/latest" \
        | grep -o "\"browser_download_url\": *\"[^\"]*$asset_name\"" \
        | head -1 | sed -E 's/.*"(https[^"]+)"/\1/'
}

curl -fsSL -o /tmp/plasma-i3-pager.plasmoid \
    "$(latest_asset_url kevinjin0420/plasma-i3-pager plasma-i3-pager.plasmoid)"
kpackagetool6 --type Plasma/Applet --install /tmp/plasma-i3-pager.plasmoid 2>/dev/null \
    || kpackagetool6 --type Plasma/Applet --upgrade /tmp/plasma-i3-pager.plasmoid

if $has_battery; then
    curl -fsSL -o /tmp/plasma-charge-limiter.plasmoid \
        "$(latest_asset_url kevinjin0420/plasma-charge-limiter plasma-charge-limiter.plasmoid)"
    kpackagetool6 --type Plasma/Applet --install /tmp/plasma-charge-limiter.plasmoid 2>/dev/null \
        || kpackagetool6 --type Plasma/Applet --upgrade /tmp/plasma-charge-limiter.plasmoid
fi

# a symlinked package dir is a local checkout; kpackagetool6 --upgrade would
# replace the link with a copy and silently detach it from the working tree
if [[ ! -L "$user_home/.local/share/kwin/tabbox/compactplus" ]]; then
    curl -fsSL -o /tmp/kwin-compact-plus.tar.gz \
        "$(latest_asset_url kevinjin0420/kwin-compact-plus kwin-compact-plus.tar.gz)"
    kpackagetool6 --type KWin/WindowSwitcher --install /tmp/kwin-compact-plus.tar.gz 2>/dev/null \
        || kpackagetool6 --type KWin/WindowSwitcher --upgrade /tmp/kwin-compact-plus.tar.gz
fi

ensure_dir "$user_home/.local/share/color-schemes" "$user_home/.local/share/plasma/desktoptheme/klassy-dark"

# A same-named user theme dir shadows the system one file-by-file, but only if
# it carries a metadata.json -- without it Plasma logs "Could not locate
# metadata for theme" and falls back to Breeze. SVGs still come from /usr.
cp /usr/share/plasma/desktoptheme/klassy-dark/metadata.json \
    "$user_home/.local/share/plasma/desktoptheme/klassy-dark/metadata.json"

cp "$dotfiles_dir/kde/color-schemes/Minimal.colors" "$user_home/.local/share/color-schemes/Minimal.colors"
cp "$dotfiles_dir/kde/color-schemes/Minimal.colors" "$user_home/.local/share/plasma/desktoptheme/klassy-dark/colors"
cp "$dotfiles_dir/kde/desktoptheme-klassy/plasmarc" "$user_home/.local/share/plasma/desktoptheme/klassy-dark/plasmarc"

plasma-apply-colorscheme Minimal

activity_id="$(grep -oP '^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}' \
    "$user_home/.config/kactivitymanagerdrc" | head -1)"

cp "$dotfiles_dir/kde/kwinrulesrc" "$user_home/.config/kwinrulesrc"

logo_icon_name="$(. /etc/os-release; echo "${LOGO:-distributor-logo}")"

logo_path=""
for size in scalable 256x256 128x128 96x96 48x48; do
    for ext in svg png; do
        f="/usr/share/icons/hicolor/$size/apps/$logo_icon_name.$ext"
        [[ -f "$f" ]] && logo_path="$f" && break 2
    done
done
if [[ -z "$logo_path" ]]; then
    for ext in svg png; do
        f="/usr/share/icons/$logo_icon_name.$ext"
        [[ -f "$f" ]] && logo_path="$f" && break
    done
fi
if [[ -z "$logo_path" ]]; then
    logo_path="$(find /usr/share/pixmaps -name "$logo_icon_name.*" 2>/dev/null | head -1)"
fi

kwc() { kwriteconfig6 "$@"; }

kwc --file kwinrc --group Desktops --key Number 5
kwc --file kwinrc --group Desktops --key Rows 1
kwc --file kwinrc --group Windows --key RollOverDesktops false
kwc --file kwinrc --group Windows --key DelayFocusInterval 0
kwc --file kwinrc --group Tiling --key padding 4
kwc --file kwinrc --group org.kde.kdecoration2 --key library org.kde.klassy
kwc --file kwinrc --group org.kde.kdecoration2 --key theme Klassy
kwc --file kwinrc --group org.kde.kdecoration2 --key BorderSize None
kwc --file kwinrc --group org.kde.kdecoration2 --key BorderSizeAuto false
kwc --file kwinrc --group TabBox --key ActivitiesMode 0
kwc --file kwinrc --group TabBox --key HighlightWindows false
kwc --file kwinrc --group TabBox --key LayoutName compactplus
kwc --file kwinrc --group Plugins --key shakecursorEnabled false
kwc --file kwinrc --group Plugins --key slideEnabled false
kwc --file kwinrc --group Plugins --key zoomEnabled false
kwc --file kwinrc --group Script-desktopchangeosd --key TextOnly true
kwc --file kwinrc --group Wayland --key EnablePrimarySelection false
kwc --file kwinrc --group Effect-showdesktop --key BorderActivate 9

kwc --file kdeglobals --group KDE --key LookAndFeelPackage org.kde.breezedark.desktop
kwc --file kdeglobals --group General --key TerminalApplication "$kitty_bin"

kwc --file klassy/klassyrc --group ButtonColors --key ButtonBackgroundOpacityActive 100
kwc --file klassy/klassyrc --group ButtonColors --key ButtonBackgroundOpacityInactive 100
kwc --file klassy/klassyrc --group ButtonColors --key CloseButtonIconColorActive AsSelected
kwc --file klassy/klassyrc --group ButtonColors --key CloseButtonIconColorInactive AsSelected
kwc --file klassy/klassyrc --group Global --key LookAndFeelSet org.kde.breezedark.desktop
kwc --file klassy/klassyrc --group ShadowStyle --key ShadowStrength 128
kwc --file klassy/klassyrc --group Windeco --key AnimationsEnabled false
kwc --file klassy/klassyrc --group Windeco --key BoldTitle false
kwc --file klassy/klassyrc --group Windeco --key ButtonIconStyle StyleTraditional
kwc --file klassy/klassyrc --group Windeco --key ButtonShape ShapeFullHeightRectangle
kwc --file klassy/klassyrc --group Windeco --key ColorizeThinWindowOutlineWithButton false
kwc --file klassy/klassyrc --group Windeco --key ColorizeWindowOutlineWithButton false
kwc --file klassy/klassyrc --group Windeco --key CornerRadius 0
kwc --file klassy/klassyrc --group Windeco --key DrawTitleBarSeparator false
kwc --file klassy/klassyrc --group Windeco --key UseTitleBarColorForAllBorders false
kwc --file klassy/klassyrc --group Windeco --key WindowCornerRadius 0
kwc --file klassy/klassyrc --group WindowOutlineStyle --key ThinWindowOutlineStyleActive WindowOutlineNone
kwc --file klassy/klassyrc --group WindowOutlineStyle --key ThinWindowOutlineStyleInactive WindowOutlineNone

kwc --file plasmarc --group Theme --key name klassy-dark
kwc --file plasmashellrc --group PlasmaViews --group "Panel 2" --key floating 0
kwc --file plasmashellrc --group PlasmaViews --group "Panel 2" --key panelOpacity 1
kwc --file plasmashellrc --group PlasmaViews --group "Panel 2" --group Defaults --key thickness 44

kwc --file plasmanotifyrc --group Notifications --key PopupPosition TopRight

kwc --file kcminputrc --group Keyboard --key RepeatDelay 200
kwc --file kcminputrc --group Keyboard --key RepeatRate 40

python3 <<'PYEOF'
import subprocess, re, os
cfg = os.path.expanduser("~/.config/kcminputrc")
try:
    text = open(cfg).read()
except FileNotFoundError:
    raise SystemExit(0)
for match in re.finditer(r'^\[Libinput\](\[[^\]]+\])+', text, re.MULTILINE):
    groups = re.findall(r'\[([^\]]+)\]', match.group(0))
    device_name = groups[-1].lower()
    if 'touchpad' not in device_name and 'trackpad' not in device_name:
        continue
    cmd = ['kwriteconfig6', '--file', 'kcminputrc']
    for g in groups:
        cmd += ['--group', g]
    cmd += ['--key', 'NaturalScroll', 'true']
    subprocess.run(cmd, check=True)
PYEOF

kwc --file powerdevilrc --group AC --group Display --key DimDisplayWhenIdle false
kwc --file powerdevilrc --group AC --group Display --key TurnOffDisplayWhenIdle false
kwc --file powerdevilrc --group AC --group Performance --key PowerProfile performance
kwc --file powerdevilrc --group AC --group SuspendAndShutdown --key AutoSuspendAction 0
kwc --file powerdevilrc --group Battery --group Display --key DimDisplayWhenIdle false
kwc --file powerdevilrc --group Battery --group Performance --key PowerProfile balanced
kwc --file powerdevilrc --group Battery --group SuspendAndShutdown --key AutoSuspendIdleTimeoutSec 900
kwc --file powerdevilrc --group BatteryManagement --key BatteryCriticalAction 1
kwc --file powerdevilrc --group LowBattery --group Performance --key PowerProfile power-saver

kwc --file kscreenlockerrc --group Daemon --key Timeout 30
kwc --file kscreenlockerrc --group Greeter --group Wallpaper --group org.kde.image --group General \
    --key Image "$dotfiles_dir/wallpapers/firewatch.png"

kwc --file breezerc --group Common --key OutlineIntensity OutlineOff
kwc --file breezerc --group Common --key ShadowStrength 128

kwc --file kglobalshortcutsrc --group kwin --key "Window Maximize" "Meta+Up,Meta+PgUp,Maximize Window"
kwc --file kglobalshortcutsrc --group kwin --key "Window Quick Tile Left" "Meta+Left,Meta+Left,Quick Tile Window to the Left"
kwc --file kglobalshortcutsrc --group kwin --key "Window Quick Tile Right" "Meta+Right,Meta+Right,Quick Tile Window to the Right"
for n in 1 2 3 4 5 6 7 8 9 10; do
    case $n in
        1) key="Alt+1,Ctrl+F1" ;; 2) key="Alt+2,Ctrl+F2" ;; 3) key="Alt+3,Ctrl+F3" ;; 4) key="Alt+4,Ctrl+F4" ;;
        5) key="Alt+5," ;; 6) key="Alt+6," ;; 7) key="Alt+7," ;; 8) key="Alt+8," ;; 9) key="Alt+9," ;; 10) key="Alt+0," ;;
    esac
    kwc --file kglobalshortcutsrc --group kwin --key "Switch to Desktop $n" "$key,Switch to Desktop $n"
done
declare -A win_desktop_keys=(
    [1]="Alt+!" [2]="Alt+@" [3]="Alt+#" [4]="Alt+\$" [5]="Alt+%"
    [6]="Alt+^" [7]="Alt+&" [8]="Alt+*" [9]="Alt+(" [10]="Alt+)"
)
for n in 1 2 3 4 5 6 7 8 9 10; do
    kwc --file kglobalshortcutsrc --group kwin --key "Window to Desktop $n" "${win_desktop_keys[$n]},,Window to Desktop $n"
done
kwc --file kglobalshortcutsrc --group kwin --key "view_zoom_in" 'none,Meta++\tMeta+=,Zoom In'
kwc --file kglobalshortcutsrc --group kwin --key "view_zoom_out" "none,Meta+-,Zoom Out"
kwc --file kglobalshortcutsrc --group kwin --key "view_actual_size" "none,Meta+0,Zoom to Actual Size"
kwc --file kglobalshortcutsrc --group kwin --key "Overview" "none,none,Toggle Overview"

kwc --file kglobalshortcutsrc --group org_kde_powerdevil --key powerProfile "none,none,Switch Power Profile"
kwc --file kglobalshortcutsrc --group krunner --key _launch "none,Alt+F2,Search"

for n in 1 2 3 4 5 6 7 8 9 10; do
    kwc --file kglobalshortcutsrc --group plasmashell --key "activate task manager entry $n" "none,none,Activate Task Manager Entry $n"
done
for n in 1 2 3 4 5 6 7 8 9 10; do
    kwriteconfig6 --file kglobalshortcutsrc --group plasmashell --key "Activate Task Manager Entry $n" --delete
done

cp "$dotfiles_dir/wallpapers/vertigo.jpg" "$user_home/.face"
cp "$dotfiles_dir/wallpapers/vertigo.jpg" "$user_home/.face.icon"
chmod 0644 "$user_home/.face" "$user_home/.face.icon"

DISPLAY=:0 plasma-apply-wallpaperimage "$dotfiles_dir/wallpapers/bryce_canyon_valley.JPG"

qdbus6 org.kde.KWin /KWin reconfigure 2>/dev/null || qdbus-qt6 org.kde.KWin /KWin reconfigure

systemctl --user stop plasma-plasmashell.service

sed -e "s#/home/kevinjin/#$user_home/#g" -e "s#__ACTIVITY__#$activity_id#g" \
    "$dotfiles_dir/kde/plasma-org.kde.plasma.desktop-appletsrc" \
    > "$user_home/.config/plasma-org.kde.plasma.desktop-appletsrc"

if [[ -n "$logo_path" ]]; then
    kwriteconfig6 --file plasma-org.kde.plasma.desktop-appletsrc \
        --group Containments --group 2 --group Applets --group 50 --group Configuration --group General \
        --key customButtonImage "$logo_path"
fi

systemctl --user start plasma-plasmashell.service
systemctl --user restart plasma-powerdevil.service
systemctl --user restart plasma-kglobalaccel.service
```

- [ ] **Step 2: Syntax-check**

Run: `bash -n setup/kde.sh`
Expected: no output, exit 0.

- [ ] **Step 3: Diff against source for the shortcut/kwriteconfig blocks**

Manually compare every `kwc`/`kwriteconfig6` line above against the corresponding `- "--file ..."` loop entry in `ansible/kde.yml` — these should be a 1:1 transcription. Flag and fix any dropped or altered key/value.

- [ ] **Step 4: Live run on this machine**

Run: `./setup/kde.sh`
Expected: exit 0; `kreadconfig6 --file kwinrc --group Desktops --key Number` reports `5`; klassy decoration is active (`kreadconfig6 --file kwinrc --group org.kde.kdecoration2 --key theme` reports `Klassy`); plasmashell restarts without error.

- [ ] **Step 5: Commit**

```bash
git add setup/kde.sh
git commit -m "migrate kde.yml to setup/kde.sh"
```

---

### Task 6: Remaining small playbooks

**Files:**
- Create: `setup/rime.sh`, `setup/envycontrol.sh`, `setup/agent.sh`, `setup/eecs482.sh`, `setup/macos.sh`
- Reference: `ansible/rime.yml`, `ansible/envycontrol.yml`, `ansible/agent.yml`, `ansible/eecs482.yml`, `ansible/macos.yml`

**Interfaces:**
- Consumes: `os_family`, `ensure_dir`, `symlink` from `setup/lib.sh`.

- [ ] **Step 1: Write `setup/rime.sh`**

```bash
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
```

- [ ] **Step 2: Write `setup/envycontrol.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/lib.sh"

[[ "$(id -u)" -ne 0 ]] || { echo "Do not run as root" >&2; exit 1; }

family="$(os_family)"
case "$family" in
    Archlinux|RedHat) ;;
    *) echo "envycontrol setup only covers Fedora and Arch -- Debian/Ubuntu already ship prime-select" >&2; exit 1 ;;
esac

if [[ "$family" == "Archlinux" ]]; then
    command -v yay >/dev/null || { echo "yay not found -- run setup/software.sh first to bootstrap the AUR helper" >&2; exit 1; }
fi

if [[ "$family" == "RedHat" ]]; then
    sudo dnf copr enable -y sunwire/envycontrol
    sudo dnf install -y python3-envycontrol
elif [[ "$family" == "Archlinux" ]]; then
    yay -S --noconfirm --needed envycontrol
fi

if command -v kwriteconfig6 >/dev/null; then
    if [[ "$family" == "Archlinux" ]]; then
        yay -S --noconfirm --needed plasma6-applets-optimus-gpu-switcher-git
    elif [[ "$family" == "RedHat" ]]; then
        # no fedora package available, github releases ships plasma 5 widget, cant use
        tmp="$(mktemp -d)"
        curl -fsSL https://github.com/enielrodriguez/optimus-gpu-switcher/archive/refs/heads/main.tar.gz \
            | tar -xz -C "$tmp" --strip-components=1
        kpackagetool6 --type Plasma/Applet --install "$tmp" 2>/dev/null \
            || kpackagetool6 --type Plasma/Applet --upgrade "$tmp"
        rm -rf "$tmp"
    fi
fi
```

- [ ] **Step 3: Write `setup/agent.sh`**

```bash
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

ensure_dir "$user_home/.cursor/rules"
symlink "$dotfiles_dir/cursor/rules/universal.mdc" "$user_home/.cursor/rules/universal.mdc"
```

- [ ] **Step 4: Write `setup/eecs482.sh`**

```bash
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
```

- [ ] **Step 5: Write `setup/macos.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail

brew tap jurplel/tap
brew install --cask jurplel/tap/instant-space-switcher
brew install --cask rectangle
```

- [ ] **Step 6: Syntax-check all five**

Run: `bash -n setup/rime.sh setup/envycontrol.sh setup/agent.sh setup/eecs482.sh setup/macos.sh`
Expected: no output, exit 0.

- [ ] **Step 7: Live-run what's testable on this machine**

Run: `./setup/agent.sh && ./setup/eecs482.sh`
Expected: both exit 0; `~/.claude/*` and `~/.cursor/rules/universal.mdc` are symlinks into the dotfiles repo; `~/.vim/plugin/version482.vim` and `~/.local/share/nvim/site/plugin/version482.vim` are symlinks to `eecs482/version482.vim`.

`setup/rime.sh` and `setup/envycontrol.sh` are reviewed against `ansible/rime.yml` / `ansible/envycontrol.yml` line-by-line but not live-run (would install IME/GPU-switching packages on the working machine). `setup/macos.sh` is review-only (no macOS available here).

- [ ] **Step 8: Commit**

```bash
git add setup/rime.sh setup/envycontrol.sh setup/agent.sh setup/eecs482.sh setup/macos.sh
git commit -m "migrate remaining playbooks to setup/*.sh"
```

---

### Task 7: Update entrypoints and docs, remove Ansible

**Files:**
- Modify: `bootstrap.sh`
- Delete: `caen.sh` (top-level)
- Modify: `README.md`
- Delete: `ansible/`, `ansible.sh`

**Interfaces:**
- Consumes: `setup/local.sh`, `setup/macos.sh`, `setup/kde.sh` (Tasks 2, 5, 6) as the scripts `bootstrap.sh` calls.

- [ ] **Step 1: Rewrite `bootstrap.sh`**

```bash
#!/bin/bash
set -euxo pipefail

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

DOTFILES_REPO="https://github.com/kevinjin0420/dotfiles"
DOTFILES_DIR="${HOME}/dotfiles"

echo -e "${BLUE}Bootstrapping${NC}"

if [ ! -d "$DOTFILES_DIR/.git" ]; then
    echo -e "${BLUE}Cloning dotfiles...${NC}"
    git clone "$DOTFILES_REPO" "$DOTFILES_DIR"
fi

echo -e "${BLUE}Running local setup...${NC}"
"$DOTFILES_DIR/setup/local.sh"

if [[ "$OSTYPE" == "darwin"* ]]; then
    echo -e "${BLUE}Running macOS setup...${NC}"
    "$DOTFILES_DIR/setup/macos.sh"
fi

if command -v kwriteconfig6 &>/dev/null; then
    echo -e "${BLUE}Running KDE setup...${NC}"
    "$DOTFILES_DIR/setup/kde.sh"
fi

echo -e "${GREEN}Setup complete!${NC}"
```

- [ ] **Step 2: Delete the top-level `caen.sh` wrapper**

Run: `git rm caen.sh`
Expected: file removed; `setup/caen.sh` (Task 4) is the direct replacement, run as `./setup/caen.sh`.

- [ ] **Step 3: Update `README.md`**

Replace the "Bootstrap" section's `install Ansible, git` / `./ansible.sh local.yml` instructions with:

```markdown
## Bootstrap

for a freshly installed OS:

- install git
- clone this repo
- run `./setup/local.sh` to start

OR, bootstrap script:

\`\`\`sh
curl -fsSL https://dotfiles.kevinjin.dev | bash
\`\`\`

then, run scripts as needed:

\`\`\`sh
./setup/<script.sh>
\`\`\`
```

and replace every `### \`<name>.yml\`` heading / `./ansible.sh <name>.yml` reference in the "Playbooks" section with `### \`<name>.sh\`` / `./setup/<name>.sh`, keeping each section's descriptive body text unchanged. Rename the section heading itself from "Playbooks" to "Setup scripts".

- [ ] **Step 4: Delete Ansible**

Run: `git rm -r ansible ansible.sh`
Expected: `ansible/` tree and `ansible.sh` removed from the working tree.

- [ ] **Step 5: Full syntax sweep**

Run: `for f in setup/*.sh bootstrap.sh; do bash -n "$f" || echo "FAIL: $f"; done`
Expected: no `FAIL` lines.

- [ ] **Step 6: Commit**

```bash
git add bootstrap.sh README.md
git add -A setup caen.sh ansible ansible.sh
git commit -m "update entrypoints and docs, remove ansible"
```
