import importlib.util
import json
import pathlib
import sys
import tempfile
import types
from unittest import mock

# focus-opacity.py imports kitty-internal modules that only exist inside kitty.
# These stubs provide the exact imported attributes before exec_module runs:
#   from kitty.colors import patch_colors
#   from kitty.fast_data_types import get_options
kitty_pkg = types.ModuleType("kitty")
kitty_colors = types.ModuleType("kitty.colors")
kitty_colors.patch_colors = lambda *a, **k: None
kitty_fdt = types.ModuleType("kitty.fast_data_types")
kitty_fdt.get_options = lambda *a, **k: None
sys.modules.setdefault("kitty", kitty_pkg)
sys.modules.setdefault("kitty.colors", kitty_colors)
sys.modules.setdefault("kitty.fast_data_types", kitty_fdt)

def load_module():
    spec = importlib.util.spec_from_file_location(
        "focus_opacity",
        pathlib.Path(__file__).parents[2] / "kitty" / "focus-opacity.py",
    )
    loaded = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(loaded)
    return loaded


mod = load_module()


def test_prism_state_dir_override():
    with mock.patch.dict("os.environ", {"PRISM_STATE_DIR": "/tmp/prism-state"}, clear=True):
        loaded = load_module()
    assert loaded.PRISM_RESOLVED == "/tmp/prism-state/resolved.json"


def test_xdg_state_home_override():
    with mock.patch.dict(
        "os.environ", {"HOME": "/tmp/home", "XDG_STATE_HOME": "/tmp/xdg-state"}, clear=True
    ):
        loaded = load_module()
    assert loaded.PRISM_RESOLVED == "/tmp/xdg-state/prism/resolved.json"


def test_reads_prism_values():
    with tempfile.TemporaryDirectory() as d:
        resolved = pathlib.Path(d) / "resolved.json"
        resolved.write_text(
            json.dumps(
                {
                    "params": {
                        "terminal.background.opacity.active": 0.9,
                        "terminal.background.opacity.inactive": 0.4,
                    }
                }
            )
        )
        mod.PRISM_RESOLVED = str(resolved)
        assert mod._opacities() == (0.9, 0.4)


def test_missing_file_falls_back_to_shipped_defaults():
    mod.PRISM_RESOLVED = "/nonexistent/resolved.json"
    assert mod._opacities() == (
        mod.ACTIVE_BACKGROUND_OPACITY,
        mod.INACTIVE_BACKGROUND_OPACITY,
    )


def test_malformed_state_fails_loudly():
    with tempfile.TemporaryDirectory() as d:
        resolved = pathlib.Path(d) / "resolved.json"
        resolved.write_text("{not json")
        mod.PRISM_RESOLVED = str(resolved)
        try:
            mod._opacities()
        except Exception:
            pass
        else:
            raise AssertionError("malformed resolved.json must raise")


def test_missing_opacity_fails_loudly():
    with tempfile.TemporaryDirectory() as d:
        resolved = pathlib.Path(d) / "resolved.json"
        resolved.write_text(json.dumps({"params": {}}))
        mod.PRISM_RESOLVED = str(resolved)
        try:
            mod._opacities()
        except KeyError:
            pass
        else:
            raise AssertionError("missing opacity params must raise")


if __name__ == "__main__":
    test_prism_state_dir_override()
    test_xdg_state_home_override()
    test_reads_prism_values()
    test_missing_file_falls_back_to_shipped_defaults()
    test_malformed_state_fails_loudly()
    test_missing_opacity_fails_loudly()
    print("ok")
