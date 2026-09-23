# dotfiles

This is my personal dotfiles repository, supporting:

- macOS
- Arch
- Debian/Ubuntu
- Fedora

basically the operating systems I use

## Bootstrap

for a freshly installed OS:

- install git
- clone this repo
- run `./setup/local.sh` to start

OR, bootstrap script:

```sh
curl -fsSL https://dotfiles.kevinjin.dev | bash
```

then, run scripts as needed:

```sh
./setup/<script.sh>
```

---

## Setup scripts

### `local.sh`

Main setup

- Installs packages
  - zsh
  - fzf
  - git
  - curl
  - kitty
  - tmux
- zsh default shell
- omz + plugins:
  - autosuggestions
  - syntax-highlighting
  - powerlevel10k
- lazyvim setup
- font suite (JetBrains Mono NL NF)
- symlink dotfiles
- udev rules

### `headless.sh`

`local.sh` but no kitty, meant for raspis, etc.

- latest stable nvim + tree-sitter CLI in `~/.local` (arm64/x86_64, 64-bit OS only)
- symlinks this repo's nvim config and restores plugins from `lazy-lock.json`

### `caen.sh`

umich caen, headless AND no sudo

### `kde.sh`

KDE Plasma config

- kwin settings
- installs desktop-status-bar

because this uses kwriteconfig6, only plasma 6 is supoported (which is perfectly reasonable)

### `macos.sh`

this is a mess, will clean up later (need to use this piece of shit DE for work)

### `rime.sh`

simplified chinese input method on kde

### `agent.sh`

tries to make claude more usable

### `eecs482.sh`

class setup, opt-in. Symlinks `eecs482/version482.vim` (course staff editor
plugin that auto-snapshots work to `*.version482` repos) into `~/.vim/plugin/`
and `~/.local/share/nvim/site/plugin/`. See `eecs482/README.md`.

### `envycontrol.sh`

installs [envycontrol](https://github.com/bayasdev/envycontrol) for Nvidia Optimus GPU switching, Fedora only for now
installs [optimus-gpu-switcher](https://github.com/enielrodriguez/optimus-gpu-switcher) plasma widget if KDE

mode switching: `envycontrol -s <integrated|hybrid|nvidia>`

---

## udev rules

Tracked in `udev/rules.d/` and symlinked into `/etc/udev/rules.d/` by `local.sh` on Linux.

| File                      | Device                                     |
| ------------------------- | ------------------------------------------ |
| `49-stlinkv1.rules`       | STM32VL discovery (ST-Link v1)             |
| `49-stlinkv2-1.rules`     | STM32 Nucleo (ST-Link v2-1)                |
| `49-stlinkv2.rules`       | STM32 discovery (ST-Link v2)               |
| `49-stlinkv3.rules`       | ST-Link v3                                 |
| `50-programmer_usb.rules` | FTDI FT2232 programmer, custom vendor 33aa |
| `50-stm32_dfu.rules`      | STM32 DFU mode                             |
| `52-digilent-usb.rules`   | Digilent FPGA/USB                          |
| `99-jlink.rules`          | SEGGER J-Link + CMSIS-DAP                  |
| `99-SaleaeLogic.rules`    | Saleae Logic analyzers                     |
