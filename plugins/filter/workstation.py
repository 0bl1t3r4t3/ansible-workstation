# -*- coding: utf-8 -*-
# MIT License
"""Filters used by the bwhitehead.workstation roles."""

from __future__ import annotations

DOCUMENTATION = r"""
name: workstation
short_description: Helper filters for the workstation roles
description:
  - C(os_packages) translates generic package names to the names used by an OS family.
  - C(parse_tool_versions) turns the text of an asdf C(.tool-versions) file into a dict.
  - C(asdf_not_installed) lists tools that C(asdf current) reports as not installed.
"""


def os_packages(packages, os_family, name_map=None):
    """Translate generic package names for ``os_family``.

    ``name_map`` is ``{generic: {OsFamily: real_name}}``. A missing entry keeps
    the generic name; an empty string skips the package on that OS.
    Order is kept and duplicates are dropped.
    """
    name_map = name_map or {}
    out, seen = [], set()
    for pkg in packages or []:
        name = (name_map.get(pkg) or {}).get(os_family, pkg)
        if name and name not in seen:
            seen.add(name)
            out.append(name)
    return out


def parse_tool_versions(text):
    """Parse asdf ``.tool-versions`` content into ``{tool: first_version}``."""
    tools = {}
    for line in (text or "").splitlines():
        line = line.split("#", 1)[0].strip()
        parts = line.split()
        if len(parts) >= 2:
            tools[parts[0]] = parts[1]
    return tools


def asdf_not_installed(text):
    """Names of tools that ``asdf current`` reports as not installed.

    asdf >= 0.16 prints ``Name Version Source Installed`` with true/false in the
    last column.
    """
    names = []
    for line in (text or "").splitlines()[1:]:
        parts = line.split()
        if len(parts) >= 4 and parts[-1] == "false":
            names.append(parts[0])
    return sorted(names)


class FilterModule:
    """Ansible filter plugin entry point."""

    def filters(self):
        return {
            "os_packages": os_packages,
            "parse_tool_versions": parse_tool_versions,
            "asdf_not_installed": asdf_not_installed,
        }
