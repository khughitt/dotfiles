import json
import os
import subprocess
import tomllib
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
PALETTE = ROOT / "noctalia/palettes/Glow.json"


def render(template: Path, output: Path) -> None:
    subprocess.run(
        [
            "noctalia",
            "theme",
            "--theme-json",
            str(PALETTE),
            "--dark",
            "-r",
            f"{template}:{output}",
        ],
        check=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.PIPE,
        text=True,
    )


def test_fzf_reads_wallpaper_palette_from_generated_options(tmp_path: Path) -> None:
    cache = tmp_path / "cache"
    options = cache / "noctalia/fzf.conf"
    options.parent.mkdir(parents=True)
    render(ROOT / "noctalia/templates/fzf.conf", options)

    env = os.environ | {"FZF_DEFAULT_OPTS_FILE": str(options)}
    result = subprocess.run(
        ["fzf", "--filter", "needle"],
        input="haystack\nneedle\n",
        env=env,
        check=True,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    assert result.stdout == "needle\n"
    assert "#15e6cf" in options.read_text()

    shell = subprocess.run(
        [
            "zsh",
            "-fc",
            'source "$1"; print -r -- "$FZF_DEFAULT_OPTS|$FZF_DEFAULT_OPTS_FILE"',
            "zsh",
            str(ROOT / "shell/fzf"),
        ],
        env=os.environ | {"XDG_CACHE_HOME": str(cache)},
        check=True,
        text=True,
        stdout=subprocess.PIPE,
    )
    assert shell.stdout == f"--exact -1|{options}\n"


def test_fastfetch_loads_generated_noctalia_config(tmp_path: Path) -> None:
    config = tmp_path / "config.jsonc"
    render(ROOT / "noctalia/templates/fastfetch.jsonc", config)

    parsed = json.loads(config.read_text())
    assert parsed["display"]["color"]["keys"] == "#15e6cf"
    subprocess.run(
        ["fastfetch", "--config", str(config), "--pipe"],
        check=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )


def test_setup_keeps_yazi_generated_flavor_outside_repo(tmp_path: Path) -> None:
    home = tmp_path / "home"
    config = tmp_path / "config"
    legacy_yazi = tmp_path / "legacy-yazi"
    (legacy_yazi / "flavors/noctalia.yazi").mkdir(parents=True)
    (legacy_yazi / "theme.toml").write_text('[flavor]\ndark = "noctalia"\n')
    (legacy_yazi / "flavors/noctalia.yazi/flavor.toml").write_text("generated\n")
    config.mkdir()
    (config / "yazi").symlink_to(legacy_yazi, target_is_directory=True)
    env = os.environ | {
        "HOME": str(home),
        "XDG_CACHE_HOME": str(tmp_path / "cache"),
        "XDG_CONFIG_HOME": str(config),
        "XDG_DATA_HOME": str(tmp_path / "data"),
        "XDG_STATE_HOME": str(tmp_path / "state"),
        "DOTFILES_OPENCODE_RUNTIME_SOURCE": str(tmp_path / "opencode-runtime"),
    }
    subprocess.run(
        [
            "bash",
            str(ROOT / "setup.sh"),
            "--link-only",
            "--headless",
            "--only",
            "common-config",
        ],
        env=env,
        check=True,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.PIPE,
        text=True,
    )

    yazi = config / "yazi"
    assert yazi.is_dir() and not yazi.is_symlink()
    assert (yazi / "yazi.toml").samefile(ROOT / "yazi/yazi.toml")
    assert (yazi / "theme.toml").is_file()
    assert (yazi / "flavors/noctalia.yazi/flavor.toml").is_file()
    assert not (legacy_yazi / "theme.toml").exists()
    assert not (legacy_yazi / "flavors").exists()
    assert (tmp_path / "cache/noctalia/fzf.conf").is_file()


def test_noctalia_registry_selects_safe_cli_templates() -> None:
    templates = tomllib.loads((ROOT / "noctalia/templates.toml").read_text())[
        "theme"
    ]["templates"]
    assert templates["community_ids"] == ["zathura", "bat", "yazi"]
    assert {"fzf", "fastfetch"} <= templates["user"].keys()


def test_generated_compositor_colors_override_tracked_defaults() -> None:
    niri = (ROOT / "niri/config.kdl").read_text()
    assert niri.rindex('include "./noctalia.kdl"') > niri.rindex("insert-hint {")


def test_julia_uses_wallpaper_controlled_terminal_slots() -> None:
    startup = (ROOT / "julia/startup.jl").read_text()
    assert "38;2" not in startup
    assert "foreground = (" not in startup
    assert 'prompt_prefix = "\\e[32m"' in startup
