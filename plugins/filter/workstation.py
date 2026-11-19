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
"""


def os_packages(packages, os_family, name_map=None, require_mapping=False):
    """Translate generic package names for ``os_family``.

    ``name_map`` is ``{generic: {OsFamily: real_name}}``. A missing entry keeps
    the generic name (or skips it when ``require_mapping`` is true, e.g. for
    winget IDs); an empty string skips the package on that OS.
    Order is kept and duplicates are dropped.
    """
    name_map = name_map or {}
    out, seen = [], set()
    for pkg in packages or []:
        name = (name_map.get(pkg) or {}).get(os_family, None if require_mapping else pkg)
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


class FilterModule:
    """Ansible filter plugin entry point."""

    def filters(self):
        return {
            "os_packages": os_packages,
            "parse_tool_versions": parse_tool_versions,
        }
