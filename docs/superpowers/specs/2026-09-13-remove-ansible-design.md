# Remove Ansible, replace with plain shell scripts

## Motivation

Ansible in this repo has become overhead rather than help:

- sudo handling is clunky — `--ask-become-pass` upfront plus a separate
  askpass-helper dance for the AUR/yay bootstrap in `software.yml`
- `become: true` escalates more broadly than any individual step needs
- debugging a failed task is opaque compared to a plain shell trace
- the module/YAML abstraction layer isn't buying anything the author
  doesn't already know how to write directly per-OS

## Scope

Full migration of all 9 playbooks (`local`, `headless`, `caen`, `software`,
`kde`, `macos`, `rime`, `agent`, `eecs482`, `envycontrol`) plus the
`bootstrap.sh` and `caen.sh` entrypoints, in one implementation pass.
`ansible/`, `ansible.sh`, and `ansible.cfg` are deleted at the end.

## Architecture

`ansible/*.yml` becomes `setup/*.sh` — one script per current playbook,
run directly (`./setup/local.sh`), no dispatcher wrapper. The wrapper
(`ansible.sh`) existed only to pass args to `ansible-playbook`; plain
bash scripts don't need that indirection.

```
setup/
  lib.sh              # shared helpers, sourced by every script
  local.sh
  headless.sh
  caen.sh
  software.sh
  kde.sh
  macos.sh
  rime.sh
  agent.sh
  eecs482.sh
  envycontrol.sh
```

Every script: `#!/usr/bin/env bash`, `set -euo pipefail`, sources
`lib.sh`. Scripts that branch per-OS today (`local`, `headless`,
`software`, `rime`) keep a `case "$(os_family)" in ... esac` at the
point where the original YAML branched — not a blanket case wrapping
the whole script. Scripts that don't branch (`kde`, `macos`, `agent`,
`eecs482`, `envycontrol`) have no case statement.

## Shared lib (`setup/lib.sh`)

- `os_family` — replaces `ansible_facts['os_family']`. Detects Darwin
  via `$OSTYPE`; otherwise reads `/etc/os-release` (`ID`/`ID_LIKE`) and
  maps to `Archlinux` / `Debian` / `RedHat`. Exits with a clear error
  message on anything unrecognized.
- `symlink SRC DEST` — `mkdir -p "$(dirname DEST)" && ln -sf SRC DEST`.
- `ensure_dir DIR...` — `mkdir -p` over each argument.
- `clone_shallow REPO DEST` — `[ -d DEST ] || git clone --depth 1 REPO DEST`.
- `setup_zsh_omz` — installs oh-my-zsh plus the 3 plugins
  (autosuggestions, syntax-highlighting, powerlevel10k). This exact
  block is duplicated verbatim today in `local.yml`, `headless.yml`,
  and `caen.yml` — factoring it out removes real triplication, not
  speculative reuse.

## Sudo model

No upfront credential grab, no `--ask-become-pass`, no `become: true`.
Individual commands that need root call `sudo` inline at the point
they need it (`sudo pacman -S ...`, `sudo cp ... /usr/share/fonts/`,
`sudo "$dotfiles_dir/scripts/deploy_udev.sh"`). Sudo prompts on first
use per script and caches for its normal window, so a script with
several root steps doesn't re-prompt per command.

`software.sh`'s yay/AUR bootstrap drops the current askpass-helper
tempfile dance (`ansible.builtin.pause` + `SUDO_ASKPASS` env var)
entirely: `makepkg -si` and `yay -S` just prompt for sudo directly at
the point they need it, same as running them by hand.

`caen.sh` never calls sudo, same as today (headless, no-sudo
environment by design).

## Idempotency

No re-implemented Ansible-style change tracking. Rely on the
underlying commands already being safe to re-run:

- `pacman -S` / `apt install` / `dnf install` are no-ops on
  already-installed packages
- `ln -sf` always overwrites correctly
- `mkdir -p` is a no-op if the dir exists
- `clone_shallow` checks dir existence before cloning

Where the current YAML does a real pre-check for *correctness* rather
than just "skip if already done" — e.g. CAEN's "only back up a
dotfile if it's a real file, not already our symlink" before
overwriting it — that check stays. It's not idempotency plumbing, it's
data-loss prevention.

## `kde.sh`

752 lines in `kde.yml`, almost entirely `kwriteconfig6 ...` invocations
looped via `shell: + changed_when: false`. These translate near 1:1
into bash arrays of arg-strings run through a `for` loop calling
`kwriteconfig6` directly. Jinja templating (activity ID substitution,
distributor logo path, `user_home` interpolation in the dumped
appletsrc) becomes plain `sed`/parameter expansion. Mechanical, long,
low-risk.

## Entrypoint updates

- `bootstrap.sh`: drop the "install Ansible" branch entirely; after
  cloning the repo, call `setup/local.sh`, then `setup/macos.sh` on
  Darwin, then `setup/kde.sh` if `kwriteconfig6` is present — same
  conditional structure it already has, just invoking the new scripts.
- `caen.sh` (top-level): deleted — redundant now that `setup/caen.sh`
  is directly runnable with no wrapper needed.
- `README.md`: bootstrap and playbook-reference sections updated to
  describe `setup/*.sh` instead of `ansible.sh <playbook>`.

## Error handling

`set -euo pipefail` in every script, matching the current `ansible.sh`
convention. No retry or rollback logic. A failed script stops
immediately; because steps are naturally idempotent, re-running after
fixing the underlying issue is safe and cheap — this replaces Ansible's
task-level retry/skip semantics rather than reimplementing them.

## Testing / verification

No CI for a single-user dotfiles repo. Verification means running the
migrated scripts on the machine available in this session (Arch +
KDE Plasma) and confirming the same end state (symlinks, kwin
settings, installed packages) as the current Ansible run produces.
Branches for platforms not available here (macOS, Fedora, Debian,
CAEN) are reviewed line-by-line against the original YAML for parity
but cannot be live-verified in this session.

## Migration order

1. `setup/lib.sh` (foundation)
2. `local.sh`, `software.sh` — heaviest, most sudo-related, most used
3. `headless.sh`, `caen.sh` — share the zsh/omz block via `lib.sh`
4. `kde.sh` — big but mechanical
5. `rime.sh`, `envycontrol.sh`, `agent.sh`, `eecs482.sh`, `macos.sh` —
   small, independent
6. Update `bootstrap.sh` and `README.md`; delete top-level `caen.sh`
7. Delete `ansible/`, `ansible.sh`
