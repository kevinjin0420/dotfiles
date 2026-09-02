#!/usr/bin/env bash

# Helper script to run Ansible playbooks
# ported from the mrover-ros2 codebase

set -euo pipefail

become_arg=(--ask-become-pass)

if [ "${1:-}" = "--no-sudo" ]; then
    become_arg=()
    shift
fi

if [ "$#" -le 0 ]; then
    echo "Usage: $0 [--no-sudo] <playbook> <args>"
    exit 1
fi

readonly ROOT_PATH="$HOME/dotfiles"
playbook="$1"
shift

ANSIBLE_CONFIG="${ROOT_PATH}/ansible/ansible.cfg" \
    ansible-playbook -i "localhost," -c local "${become_arg[@]}" "${ROOT_PATH}/ansible/${playbook}" "$@"
