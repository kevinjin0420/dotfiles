#!/bin/bash

set -u

readonly launcher_desktop=/usr/share/applications/fcitx5-wayland-launcher.desktop

reconfigure_kwin() {
    busctl --user call org.kde.KWin /KWin org.kde.KWin reconfigure
}

# KWin only relaunches its input method when the configured launcher changes.
kwriteconfig6 --notify --file kwinrc --group Wayland --key InputMethod --delete
reconfigure_kwin
pkill -x fcitx5
kwriteconfig6 --notify --file kwinrc --group Wayland --key InputMethod "$launcher_desktop"
reconfigure_kwin
