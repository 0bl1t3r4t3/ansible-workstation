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
for v in 3.12.0 3.11.0; do test -d "${home}/.asdf/installs/shfmt/${v}" || { echo "asdf did not install shfmt ${v}" >&2; exit 1; }; done
# Run from home, where ~/.tool-versions pins the version.
(cd "${home}" && PATH=${home}/.local/bin:/opt/homebrew/bin:${PATH} ASDF_DATA_DIR=${home}/.asdf "${home}/.asdf/shims/shfmt" --version)
# Template copied and owner-only; templates/ itself is not stowed.
test "$(stat -c %a "${home}/.authinfo" 2>/dev/null || stat -f %Lp "${home}/.authinfo")" = 600 || { echo "${home}/.authinfo missing or not 600" >&2; exit 1; }
test ! -e "${home}/authinfo.example" || { echo "templates/ was stowed" >&2; exit 1; }
if [[ $(uname) == Darwin ]]; then
  brew list --pinned | grep -qx starship || { echo "starship is not pinned" >&2; exit 1; }
fi
command -v jq >/dev/null || { echo "jq (from the ci group) is missing" >&2; exit 1; }
! command -v cowsay >/dev/null || { echo "cowsay (disabled group) was installed" >&2; exit 1; }
echo "CI OK"
