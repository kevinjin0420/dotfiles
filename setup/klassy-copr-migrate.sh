#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$script_dir/lib.sh"

[[ "$(id -u)" -ne 0 ]] || { echo "Do not run as root" >&2; exit 1; }
[[ "$(os_family)" == RedHat ]] || { echo "klassy repo migration only applies to Fedora" >&2; exit 1; }

# OBS only builds klassy for Rawhide, whose newer Qt blocks dnf system-upgrade on stable Fedora
obs_repo_id="home_paulmcauley"
copr_repo_id="copr:copr.fedorainfracloud.org:errornointernet:klassy"

klassy_origin() {
    dnf repoquery --installed --qf '%{from_repo}\n' klassy
}

rpm -q klassy >/dev/null 2>&1 || { echo "klassy is not installed as an rpm, nothing to migrate" >&2; exit 1; }

current_origin="$(klassy_origin)"
if [[ "$current_origin" == "$copr_repo_id" ]]; then
    echo "klassy already comes from $copr_repo_id"
    exit 0
fi
[[ "$current_origin" == "$obs_repo_id" ]] \
    || { echo "klassy comes from unexpected repo '$current_origin', refusing to touch it" >&2; exit 1; }

sudo dnf copr enable -y errornointernet/klassy
sudo dnf config-manager disable "$obs_repo_id"
sudo dnf distro-sync -y klassy

migrated_origin="$(klassy_origin)"
[[ "$migrated_origin" == "$copr_repo_id" ]] \
    || { echo "klassy is still installed from '$migrated_origin', expected $copr_repo_id" >&2; exit 1; }
echo "klassy now comes from $copr_repo_id"
