#!/usr/bin/env bash
# CI, inside WSL on a Windows runner: configure the Windows host over SSH twice;
# the second run must change nothing.
set -euo pipefail
src=$(cd "$(dirname "$0")/../.." && pwd)
# /mnt/* is world-writable, where Ansible ignores ansible.cfg, so work from a copy.
rm -rf "${HOME}/aw" && cp -R "${src}" "${HOME}/aw" && cd "${HOME}/aw"
python3 -m venv "${HOME}/venv" && "${HOME}/venv/bin/pip" install -q ansible-core
export PATH=${HOME}/venv/bin:${PATH}
WORKSTATION_DIR=${HOME}/aw WORKSTATION_INVENTORY=tests/ci/local.yml ./scripts/bootstrap-wsl.sh --inventory-only
./scripts/dev-setup.sh
export ANSIBLE_FORCE_COLOR=1
inv=(-i tests/ci/local.yml -i tests/ci/inventory-windows.yml)
ansible-playbook "${inv[@]}" playbooks/workstation.yml
ansible-playbook "${inv[@]}" playbooks/workstation.yml | tee /tmp/run2.log
grep -Eq 'changed=0 +unreachable=0 +failed=0' /tmp/run2.log || { echo "Not idempotent" >&2; exit 1; }
# Spot checks on the Windows side (PowerShell expands these, not bash)
# shellcheck disable=SC2016
ansible "${inv[@]}" windows -m ansible.windows.win_shell -a \
  '(Get-Item $env:USERPROFILE\.config\starship.toml).LinkType; (Get-Command starship).Source; git config --global credential.helper'
echo "CI OK"
