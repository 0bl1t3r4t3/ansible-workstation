#!/usr/bin/env bash
# Make this checkout usable as bwhitehead.workstation without installing it:
# links the repo into ./.collections and installs dependencies there.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .collections/ansible_collections/bwhitehead
ln -sfn ../../.. .collections/ansible_collections/bwhitehead/workstation
ansible-galaxy collection install -r requirements.yml -p .collections >/dev/null
echo "Ready: ansible-playbook playbooks/workstation.yml --check --diff"
