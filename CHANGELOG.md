# Changelog

## Unreleased
- packages: package groups (`packages_group_definitions`, `packages_groups`) — named sets
  switched on per machine; new `package_groups` filter. The Mac list is split into 11 groups;
  the default profile is a development / sysadmin workstation.
- asdf: install every version listed on a `.tool-versions` line, not only the first
  (new `tool_version_pairs` filter).
- packages: `packages_homebrew_absent` uninstalls formulae; the profile removes telnet, ncftp,
  sshpass, chntpw, bcrypt, beecrypt and Python 3.11/3.12 (Python is now 3.15 + 3.14).
- packages: `packages_homebrew_pinned` — `brew pin` formulae so upgrades skip them
  (inventory pins tree-sitter, which emacs-plus@31 links against).
- dotfiles: copy secret-file templates (`templates/authinfo.example`, `templates/awsrc.example`)
  into place when missing, owner-only; `dotfiles_stow_exclude` keeps `templates/` from being stowed.

## 0.2.0 (2026-11-19)
- Windows support: winget packages, dotfiles linking, PowerShell profile + Windows
  Terminal, new `windows_settings` and `wsl` roles, `bootstrap.ps1` / `bootstrap-wsl.sh`.
- dotfiles: per-OS `~/.config/git/os.gitconfig`; token-based clone of private repos.
- asdf: install plugin prerequisites on Linux; detect installed versions reliably.

## 0.1.0 (2026-11-19)
- Initial roles: packages, dotfiles, shell, asdf, macos_defaults.
- Filters: `os_packages`, `parse_tool_versions`.
