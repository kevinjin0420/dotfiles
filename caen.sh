#!/usr/bin/env bash

# Run the CAEN playbook: no sudo, everything into $HOME.

set -euo pipefail

readonly ROOT_PATH="$HOME/dotfiles"
ANSIBLE_CONFIG="${ROOT_PATH}/ansible/ansible.cfg" \
    ansible-playbook -i "localhost," -c local "${ROOT_PATH}/ansible/caen.yml" "$@"
