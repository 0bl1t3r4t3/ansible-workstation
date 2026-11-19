# Changelog

## 0.2.0 (2026-11-19)
- Windows support: winget packages, dotfiles linking, PowerShell profile + Windows
  Terminal, new `windows_settings` and `wsl` roles, `bootstrap.ps1` / `bootstrap-wsl.sh`.
- dotfiles: per-OS `~/.config/git/os.gitconfig`; token-based clone of private repos.
- asdf: install plugin prerequisites on Linux; detect installed versions reliably.

## 0.1.0 (2026-11-19)
- Initial roles: packages, dotfiles, shell, asdf, macos_defaults.
- Filters: `os_packages`, `parse_tool_versions`.
