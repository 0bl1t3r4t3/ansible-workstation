# Changelog

## Unreleased
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
