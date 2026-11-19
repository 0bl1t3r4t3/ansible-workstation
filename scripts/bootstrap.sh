#!/usr/bin/env bash
# Fresh machine: install the prerequisites (Homebrew/Xcode tools on macOS, pipx on
# Linux), Ansible and git, then run the workstation playbook from this checkout.
# Usage: ./scripts/bootstrap.sh [extra ansible-playbook args, e.g. --tags packages]
set -euo pipefail
cd "$(dirname "$0")/.."

case "$(uname -s)" in
Darwin)
  if ! xcode-select -p >/dev/null 2>&1; then
    xcode-select --install || true
    echo "Finish installing the Command Line Tools, then re-run $0" >&2
    exit 1
  fi
  if ! command -v brew >/dev/null && [[ ! -x /opt/homebrew/bin/brew && ! -x /usr/local/bin/brew ]]; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi
  for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do [[ -x $b ]] && eval "$("$b" shellenv)" && break; done
  brew install ansible git stow
  ;;
Linux)
  if command -v apt-get >/dev/null; then sudo apt-get update -qq && sudo apt-get install -y git pipx stow
  elif command -v dnf >/dev/null; then sudo dnf install -y git pipx stow
  elif command -v pacman >/dev/null; then sudo pacman -Sy --needed --noconfirm git python-pipx stow
  elif command -v zypper >/dev/null; then sudo zypper install -y git python3-pipx stow
  else echo "Unsupported Linux: install git, stow and ansible-core yourself" >&2; exit 1
  fi
  # Distro ansible is often too old (needs ansible-core >= 2.16).
  pipx install --force ansible-core >/dev/null
  export PATH=$HOME/.local/bin:$PATH
  ;;
*) echo "Unsupported OS: $(uname -s)" >&2; exit 1 ;;
esac

./scripts/dev-setup.sh
exec ansible-playbook playbooks/workstation.yml --ask-become-pass "$@"
