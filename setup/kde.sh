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
    [[ -n "$(find /usr /usr/local -name '*klassy*' -name '*.so' -print -quit 2>/dev/null)" ]]
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
    local release_json
    release_json="$(curl -fsSL "https://api.github.com/repos/$repo/releases/latest")"
    printf '%s' "$release_json" \
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

activity_id="$(grep -m1 -oP '^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}' \
    "$user_home/.config/kactivitymanagerdrc" || true)"
[[ -n "$activity_id" ]] || { echo "no activity id in kactivitymanagerdrc -- panel layout would be deployed to a dead activity" >&2; exit 1; }

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
    logo_path="$(find /usr/share/pixmaps -name "$logo_icon_name.*" -print -quit 2>/dev/null)"
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
# on wayland kwin hosts the shortcuts server, so the standalone unit just loses the bus name and dies.
# reconfigure/restarting that unit never reloads kwin's own global shortcuts (Switch to Desktop,
# Window Maximize, etc) either -- kwin only reads kglobalshortcutsrc for those at process start, so
# replace it in place to pick up the new bindings without a full logout.
if systemctl --user is-active --quiet plasma-kglobalaccel.service; then
    systemctl --user restart plasma-kglobalaccel.service
else
    kwin_wayland --replace &
    disown
fi
