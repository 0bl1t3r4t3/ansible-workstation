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


def test_parse_tool_versions():
    text = "# comment\npython 3.12.7 3.11.9\n\nnodejs 24.5.0  # lts\nbroken\n"
    assert f.parse_tool_versions(text) == {"python": "3.12.7", "nodejs": "24.5.0"}
    assert f.parse_tool_versions("") == {}


def test_asdf_not_installed():
    out = (
        "Name                 Version         Source                    Installed\n"
        "python               3.12.7          /home/u/.tool-versions    true\n"
        "nodejs               24.5.0          /home/u/.tool-versions    false\n"
        "awscli               2.0.0           /home/u/.tool-versions    false\n"
    )
    assert f.asdf_not_installed(out) == ["awscli", "nodejs"]
    assert f.asdf_not_installed("") == []


def test_filter_module_exports():
    assert set(f.FilterModule().filters()) == {
        "os_packages", "parse_tool_versions", "asdf_not_installed"}
