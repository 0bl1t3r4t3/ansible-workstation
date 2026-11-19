#!/usr/bin/env bash
# Build the fixture dotfiles repo, run the playbook twice, fail unless run 2 is idempotent.
set -euo pipefail
cd "$(dirname "$0")/../.."
rm -rf /tmp/dotfiles-fixture && cp -R tests/fixtures/dotfiles /tmp/dotfiles-fixture
git -C /tmp/dotfiles-fixture init -q -b main
git -C /tmp/dotfiles-fixture -c user.email=ci@example.invalid -c user.name=ci add -A
git -C /tmp/dotfiles-fixture -c user.email=ci@example.invalid -c user.name=ci commit -qm fixture
./scripts/dev-setup.sh
export ANSIBLE_FORCE_COLOR=1
ansible-playbook -i tests/ci/inventory.yml playbooks/workstation.yml
ansible-playbook -i tests/ci/inventory.yml playbooks/workstation.yml | tee /tmp/run2.log
grep -Eq 'changed=0 +unreachable=0 +failed=0' /tmp/run2.log || { echo "Not idempotent" >&2; exit 1; }
# The playbook uses the account's real home; CI containers point $HOME elsewhere.
home=$(python3 -c 'import os, pwd; print(pwd.getpwuid(os.getuid()).pw_dir)')
test -L "${home}/.bashrc" || { echo "${home}/.bashrc is not linked" >&2; exit 1; }
test -d "${home}/.asdf/installs/shfmt/3.12.0" || { echo "asdf did not install shfmt" >&2; exit 1; }
PATH=${home}/.local/bin:/opt/homebrew/bin:${PATH} ASDF_DATA_DIR=${home}/.asdf "${home}/.asdf/shims/shfmt" --version
echo "CI OK"
