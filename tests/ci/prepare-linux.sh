#!/bin/sh
# Prepare a bare distro container: python, sudo, git, tar, ansible-core.
set -eu
if command -v apt-get >/dev/null; then
  apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get install -y -qq python3 python3-venv sudo git ca-certificates tar gzip
elif command -v dnf >/dev/null; then
  dnf install -y -q python3 sudo git tar gzip findutils shadow-utils
elif command -v pacman >/dev/null; then
  pacman -Syu --noconfirm --needed python sudo git tar gzip
fi
python3 -m venv /opt/ansible
/opt/ansible/bin/pip install -q ansible-core
