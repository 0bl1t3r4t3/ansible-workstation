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


def tool_version_pairs(text):
    """Every installable ``{tool, version}`` in ``.tool-versions`` content.

    A line may list several versions (``python 3.15.2 3.14.10``): the first is the
    default, the rest are also installed. ``system``, ``ref:...`` and ``path:...``
    are not installable and are skipped.
    """
    pairs = []
    for line in (text or "").splitlines():
        parts = line.split("#", 1)[0].split()
        for version in parts[1:]:
            if version == "system" or version.startswith(("ref:", "path:")):
                continue
            pair = {"tool": parts[0], "version": version}
            if pair not in pairs:
                pairs.append(pair)
    return pairs


PACKAGE_GROUP_KEYS = (
    "common", "homebrew_taps", "homebrew_formulae", "homebrew_casks",
    "homebrew_pinned", "linux", "flatpaks", "winget",
)


def package_groups(base, enabled, definitions):
    """Merge the enabled groups' package lists into base.

    base: {key: [..]} for each of PACKAGE_GROUP_KEYS (missing keys count as []).
    enabled: group names, in order. definitions: {name: {key: [..], ...}}.
    Returns {key: [..]} with base entries first, then each group's, de-duplicated.
    Unknown group names raise an error that lists the defined ones.
    """
    definitions = definitions or {}
    unknown = [g for g in (enabled or []) if g not in definitions]
    if unknown:
        raise ValueError(
            "Unknown package group(s): %s. Defined: %s"
            % (", ".join(unknown), ", ".join(sorted(definitions)))
        )
    out = {}
    for key in PACKAGE_GROUP_KEYS:
        merged = []
        for source in [base or {}] + [definitions[g] for g in (enabled or [])]:
            for name in source.get(key) or []:
                if name not in merged:
                    merged.append(name)
        out[key] = merged
    return out


class FilterModule:
    """Ansible filter plugin entry point."""

    def filters(self):
        return {
            "os_packages": os_packages,
            "package_groups": package_groups,
            "parse_tool_versions": parse_tool_versions,
            "tool_version_pairs": tool_version_pairs,
        }
