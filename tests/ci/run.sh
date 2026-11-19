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
test -L "$HOME/.bashrc" && "$HOME/.asdf/shims/shfmt" --version
echo "CI OK"
