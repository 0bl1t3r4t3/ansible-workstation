# bwhitehead.workstation

Ansible collection that sets up a workstation on **macOS, Linux and Windows**
(Linux: Debian/Ubuntu, Fedora/RHEL, Arch; openSUSE best-effort): installs apps,
links dotfiles, sets up the shell and Starship prompt, installs asdf tool versions
and applies OS settings.
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

**A Windows PC** (Ansible can't run on Windows itself, so it runs in WSL and
configures Windows over SSH, plus the WSL Linux environment, in one run):
1. In an **elevated** PowerShell:
   ```powershell
   irm https://raw.githubusercontent.com/0bl1t3r4t3/ansible-workstation/main/scripts/bootstrap.ps1 -OutFile bootstrap.ps1
   powershell -ExecutionPolicy Bypass -File .\bootstrap.ps1
   ```
   Enables the OpenSSH Server (key-only; localhost-only on Windows 11), creates an SSH
   key for Ansible, and installs WSL + Ubuntu. Reboot if asked, open Ubuntu once.
2. In WSL:
   ```sh
   curl -fsSL https://raw.githubusercontent.com/0bl1t3r4t3/ansible-workstation/main/scripts/bootstrap-wsl.sh | bash
   ```
   Installs Ansible, writes `inventory/local.yml` for the Windows host and runs the
   playbook. Later runs: `cd ~/src/ansible-workstation && ansible-playbook playbooks/workstation.yml -K`.
   Use `--limit windows` or `--limit localhost` to do one side only.

## Roles (run in this order by `playbooks/workstation.yml`)

| Role | Does | Key variables |
|---|---|---|
| `packages` | Homebrew taps/formulae/casks (macOS); apt/dnf/pacman/zypper + Flatpak (Linux); winget (Windows) | `packages_common` (generic names, translated per OS), `packages_homebrew_*`, `packages_debian` / `_redhat` / `_archlinux`, `packages_flatpaks`, `packages_winget`, `packages_upgrade` |
| `dotfiles` | Clones the dotfiles repo, backs up files that are in the way, links it (GNU Stow; a PowerShell equivalent on Windows); writes per-OS git settings | `dotfiles_repo`, `dotfiles_packages`, `dotfiles_windows_packages`, `dotfiles_update`, `dotfiles_git_token`, `dotfiles_git_os_config` |
| `shell` | Login shell (Homebrew bash on macOS), Starship on Linux; on Windows: `$PROFILE` loads the dotfiles PowerShell profile, Windows Terminal defaults to PowerShell 7 + Nerd Font | `shell_login`, `shell_starship`, `shell_windows_terminal*` |
| `asdf` | Installs asdf, the plugins and every version in `~/.tool-versions` (not on Windows; WSL gets it) | `asdf_plugin_urls`, `asdf_install_versions`, `asdf_version` (Linux) |
| `macos_defaults` | `defaults write` settings, restarts Dock/Finder when needed | `macos_defaults_settings` |
| `windows_settings` | Registry settings (Explorer, theme, ...), Developer Mode | `windows_settings_registry`, `windows_settings_developer_mode` |
| `wsl` | Installs WSL distributions, manages `.wslconfig` | `wsl_distributions`, `wsl_config` |

Defaults are in each `roles/*/defaults/main.yml`.

## My profile
`inventory/group_vars/all/` holds the settings for my machines:
- `packages.yml` - cross-OS CLI tools, plus every Homebrew formula/cask/tap on the main Mac (Nov 2026).
- `asdf.yml` - plugin URLs. Versions come from `~/.tool-versions` in the dotfiles repo.
- `../windows.yml` - winget apps, dark mode + file extensions, WSL with mirrored networking.

Generic package names follow Homebrew; `roles/packages/vars/main.yml` maps the
ones that differ (e.g. `fd` -> `fd-find` on Debian). Map a name to `""` to skip it on an OS.

## Sudo / admin
Only these tasks use sudo: Linux package installs, adding a shell to `/etc/shells`,
and changing the login shell. The last two run only when something actually needs
to change, so a re-run on a configured Mac needs no password.
On Windows, the SSH session of an administrator account is already elevated.

## Private dotfiles repo
Set `DOTFILES_GIT_TOKEN` (bootstrap-wsl.sh uses `gh auth token` or asks) to clone
over HTTPS. The token is passed to git through environment variables only, never
written to disk, and hidden from Ansible output.

## Development
```sh
ansible-lint                          # production profile
python3 -m pytest -q tests/unit       # filter plugin tests
tests/ci/run.sh                       # what CI runs: 2 passes, second must report changed=0
```
CI (`.github/workflows/ci.yml`) lints (ansible-lint, pytest, shellcheck,
PSScriptAnalyzer), then runs the playbook twice in Debian 12, Ubuntu 24.04,
Fedora 41 and Arch containers, on a macOS runner, and on a Windows runner (from
WSL over SSH, like a real PC), using small CI profiles and a fixture dotfiles repo.

## Roadmap
- App Store apps (`mas`), Dock layout, more macOS defaults
- Per-host profiles (`inventory/host_vars/`) for work vs personal machines
- Role argument specs for input validation
- Windows: Scoop for CLI tools, more registry presets
