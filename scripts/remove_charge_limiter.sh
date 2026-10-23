#!/bin/bash
set -euo pipefail

if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "remove_charge_limiter.sh is not applicable on macOS" >&2
    exit 0
fi

plugin_id="org.kevinjin.plasma.chargelimit"
appletsrc="$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"

systemctl --user stop plasma-plasmashell.service

if [[ -f "$appletsrc" ]]; then
    # drop every [...][Applets][N] section (and its subsections) whose plugin is the widget
    awk -v plugin_id="$plugin_id" '
        NR == FNR {
            if ($0 ~ /^\[/) header = $0
            if ($0 == "plugin=" plugin_id) {
                sub(/\]$/, "", header)
                doomed[header] = 1
            }
            next
        }
        /^\[/ {
            skipping = 0
            for (prefix in doomed) {
                if (index($0, prefix "]") == 1) skipping = 1
            }
        }
        !skipping
    ' "$appletsrc" "$appletsrc" \
        | sed -e "s/,$plugin_id//g" -e "s/=$plugin_id,/=/" -e "s/=$plugin_id\$/=/" \
        > "$appletsrc.tmp"
    mv "$appletsrc.tmp" "$appletsrc"
fi

if kpackagetool6 --type Plasma/Applet --show "$plugin_id" >/dev/null 2>&1; then
    kpackagetool6 --type Plasma/Applet --remove "$plugin_id"
fi

systemctl --user start plasma-plasmashell.service
