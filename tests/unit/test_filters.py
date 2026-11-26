"""Unit tests for plugins/filter/workstation.py (run: python3 -m pytest tests/unit)."""
import importlib.util
import pathlib

_path = pathlib.Path(__file__).resolve().parents[2] / "plugins" / "filter" / "workstation.py"
_spec = importlib.util.spec_from_file_location("workstation_filters", _path)
f = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(f)

MAP = {"fd": {"Debian": "fd-find", "RedHat": "fd-find"}, "gnu-sed": {"Debian": ""}}


def test_os_packages_maps_skips_and_dedupes():
    pkgs = ["git", "fd", "gnu-sed", "git"]
    assert f.os_packages(pkgs, "Debian", MAP) == ["git", "fd-find"]
    assert f.os_packages(pkgs, "Darwin", MAP) == ["git", "fd", "gnu-sed"]
    assert f.os_packages(None, "Darwin") == []


def test_os_packages_require_mapping():
    win = {"git": {"Windows": "Git.Git"}, "fd": {"Windows": ""}}
    assert f.os_packages(["git", "fd", "jq"], "Windows", win, require_mapping=True) == ["Git.Git"]


def test_parse_tool_versions():
    text = "# comment\npython 3.12.7 3.11.9\n\nnodejs 24.5.0  # lts\nbroken\n"
    assert f.parse_tool_versions(text) == {"python": "3.12.7", "nodejs": "24.5.0"}
    assert f.parse_tool_versions("") == {}


def test_filter_module_exports():
    assert set(f.FilterModule().filters()) == {"os_packages", "package_groups", "parse_tool_versions", "tool_version_pairs"}


def test_package_groups_merges_in_order_and_dedupes():
    defs = {
        "core": {"homebrew_formulae": ["tmux", "gh"], "description": "x"},
        "dev": {"homebrew_formulae": ["gh", "uv"], "homebrew_casks": ["vimr"], "common": ["jq"]},
    }
    base = {"homebrew_formulae": ["starship"], "common": ["git"]}
    out = f.package_groups(base, ["core", "dev"], defs)
    assert out["homebrew_formulae"] == ["starship", "tmux", "gh", "uv"]
    assert out["homebrew_casks"] == ["vimr"]
    assert out["common"] == ["git", "jq"]
    assert out["winget"] == []
    assert f.package_groups(None, None, None)["common"] == []


def test_package_groups_unknown_group():
    import pytest

    with pytest.raises(ValueError, match="Unknown package group.*nope.*Defined: core"):
        f.package_groups({}, ["nope"], {"core": {}})


def test_tool_version_pairs():
    text = "python 3.15.2 3.14.10  # newest + prior\nnodejs system 24.5.0\nruby ref:main\nbroken\n"
    assert f.tool_version_pairs(text) == [
        {"tool": "python", "version": "3.15.2"},
        {"tool": "python", "version": "3.14.10"},
        {"tool": "nodejs", "version": "24.5.0"},
    ]
    assert f.tool_version_pairs(None) == []
