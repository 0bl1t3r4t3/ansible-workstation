# bwhitehead.workstation

Ansible collection that sets up a workstation on **macOS and Linux** (Debian/Ubuntu,
Fedora/RHEL, Arch; openSUSE best-effort): installs apps, links dotfiles, sets the
login shell and prompt, installs asdf tool versions and applies macOS settings.
Every role is idempotent and safe to re-run; `--check --diff` shows what would change.

## Quick start

**This Mac (or any machine with Ansible):**
```sh
./scripts/dev-setup.sh                                   # once per clone
ansible-playbook playbooks/workstation.yml --check --diff # preview
ansible-playbook playbooks/workstation.yml -K             # apply (-K = sudo password)
ansible-playbook playbooks/workstation.yml --tags dotfiles,shell
```

**A fresh machine:**
```sh
git clone https://github.com/0bl1t3r4t3/ansible-workstation.git ~/src/ansible-workstation
~/src/ansible-workstation/scripts/bootstrap.sh
```
`bootstrap.sh` installs the Xcode Command Line Tools + Homebrew (macOS) or pipx
(Linux), Ansible, git and stow, then runs the playbook. The dotfiles repo is
private, so log in first (`gh auth login && gh auth setup-git`) or set
`dotfiles_repo` to an SSH URL.

## Roles (run in this order by `playbooks/workstation.yml`)

| Role | Does | Key variables |
|---|---|---|
| `packages` | Homebrew taps/formulae/casks on macOS; apt/dnf/pacman/zypper + Flatpak on Linux | `packages_common` (generic names, translated per OS), `packages_homebrew_*`, `packages_debian` / `_redhat` / `_archlinux`, `packages_flatpaks`, `packages_upgrade` |
| `dotfiles` | Clones the dotfiles repo, backs up files that are in the way, links it with GNU Stow | `dotfiles_repo`, `dotfiles_dest`, `dotfiles_packages`, `dotfiles_update`, `dotfiles_backup_conflicts` |
| `shell` | Sets the login shell (Homebrew bash on macOS); installs Starship on Linux | `shell_login`, `shell_paths`, `shell_starship` |
| `asdf` | Installs asdf, the plugins and every version in `~/.tool-versions` | `asdf_plugin_urls`, `asdf_install_versions`, `asdf_version` (Linux) |
| `macos_defaults` | `defaults write` settings, restarts Dock/Finder when needed | `macos_defaults_settings` |

Defaults are in each `roles/*/defaults/main.yml`.

## My profile
`inventory/group_vars/all/` holds the settings for my machines:
- `packages.yml` - cross-OS CLI tools, plus every Homebrew formula/cask/tap on the main Mac (Nov 2026).
- `asdf.yml` - plugin URLs. Versions come from `~/.tool-versions` in the dotfiles repo.

Generic package names follow Homebrew; `roles/packages/vars/main.yml` maps the
ones that differ (e.g. `fd` -> `fd-find` on Debian). Map a name to `""` to skip it on an OS.

## Sudo
Only these tasks use sudo: Linux package installs, adding a shell to `/etc/shells`,
and changing the login shell. The last two run only when something actually needs
to change, so a re-run on a configured Mac needs no password.

## Development
```sh
ansible-lint                          # production profile
python3 -m pytest -q tests/unit       # filter plugin tests
tests/ci/run.sh                       # what CI runs: 2 passes, second must report changed=0
```
CI (`.github/workflows/ci.yml`) lints, then runs the playbook in Debian 12,
Ubuntu 24.04, Fedora 41 and Arch containers and on a macOS runner, using the
small profile in `tests/ci/inventory.yml` and a fixture dotfiles repo.

## Roadmap
- App Store apps (`mas`), Dock layout, more macOS defaults
- Per-host profiles (`inventory/host_vars/`) for work vs personal machines
- Role argument specs for input validation
- Windows (winget/Scoop) - maybe
