#!/usr/bin/env bash
# Run inside WSL after scripts/bootstrap.ps1. Installs Ansible here, connects to
# the Windows host over SSH with the key bootstrap.ps1 created, writes
# inventory/local.yml, then runs the playbook for Windows AND this WSL distro.
#
# Usage: bootstrap-wsl.sh [--inventory-only] [extra ansible-playbook args]
set -euo pipefail
REPO=${WORKSTATION_REPO:-https://github.com/0bl1t3r4t3/ansible-workstation.git}
DEST=${WORKSTATION_DIR:-${HOME}/src/ansible-workstation}
KEY=${HOME}/.ssh/ansible_workstation_ed25519
INVENTORY=${WORKSTATION_INVENTORY:-inventory/local.yml}   # relative to the repo
inventory_only=false
[[ ${1:-} == --inventory-only ]] && { inventory_only=true; shift; }

grep -qi microsoft /proc/sys/kernel/osrelease 2>/dev/null || { echo "Run this inside WSL." >&2; exit 1; }
SUDO=; [[ $(id -u) -eq 0 ]] || SUDO=sudo

echo "==> Packages (git, ssh, pipx)"
if command -v apt-get >/dev/null; then ${SUDO} apt-get update -qq && ${SUDO} apt-get install -y -qq git openssh-client pipx
elif command -v dnf >/dev/null; then ${SUDO} dnf install -y -q git openssh-clients pipx
elif command -v pacman >/dev/null; then ${SUDO} pacman -Sy --needed --noconfirm git openssh python-pipx
fi
export PATH=${HOME}/.local/bin:${PATH}
command -v ansible-playbook >/dev/null || pipx install --include-deps ansible-core >/dev/null

echo "==> Workstation repo"
[[ -d ${DEST}/.git ]] || git clone -q "${REPO}" "${DEST}"
cd "${DEST}"

echo "==> SSH to Windows"
win() { cmd.exe /d /c "$1" 2>/dev/null | tr -d '\r'; }
win_user=$(win 'echo %USERNAME%')
win_home=$(wslpath "$(win 'echo %USERPROFILE%')")
install -d -m 700 "${HOME}/.ssh"
install -m 600 "${win_home}/.ssh/ansible_workstation_ed25519" "${KEY}"
ssh_ok() { ssh -i "${KEY}" -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=accept-new "${win_user}@$1" exit 2>/dev/null; }
host=127.0.0.1   # mirrored networking (Windows 11)
if ! ssh_ok "${host}"; then
  host=$(ip route show default | awk '{print $3; exit}')   # NAT networking (Windows 10)
  ssh_ok "${host}" || { echo "Cannot SSH to Windows as ${win_user} (tried 127.0.0.1 and ${host}). Did bootstrap.ps1 finish?" >&2; exit 1; }
fi
mkdir -p "$(dirname "${INVENTORY}")"
cat > "${INVENTORY}" <<YAML
---
# Written by scripts/bootstrap-wsl.sh: this PC's Windows side.
all:
  children:
    windows:
      hosts:
        windows:
          ansible_host: ${host}
          ansible_user: "${win_user}"
          ansible_connection: ssh
          ansible_shell_type: powershell
          ansible_ssh_private_key_file: ${KEY}
YAML
echo "Windows host: ${win_user}@${host}"
${inventory_only} && exit 0

./scripts/dev-setup.sh
# Private dotfiles repo: pass a GitHub token for the clone (not stored).
if [[ -z ${DOTFILES_GIT_TOKEN:-} ]] && command -v gh >/dev/null && gh auth status >/dev/null 2>&1; then
  DOTFILES_GIT_TOKEN=$(gh auth token); export DOTFILES_GIT_TOKEN
fi
if [[ -z ${DOTFILES_GIT_TOKEN:-} ]]; then
  read -rsp "GitHub token for the private dotfiles repo (Enter to skip): " DOTFILES_GIT_TOKEN </dev/tty || true
  echo; export DOTFILES_GIT_TOKEN
fi
exec ansible-playbook playbooks/workstation.yml --ask-become-pass "$@"
