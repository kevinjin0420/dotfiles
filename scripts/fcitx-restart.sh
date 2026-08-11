#!/bin/bash

pkill -x fcitx5
setsid fcitx5 -d --replace >/dev/null 2>&1 < /dev/null &
disown
