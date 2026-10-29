import json
import os
import subprocess
import tempfile
import tomllib
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
PALETTE = ROOT / "noctalia/palettes/Glow.json"


def render(template: Path, output: Path) -> None:
    # The Noctalia CLI migrates the settings.toml under XDG_STATE_HOME as a side
    # effect, so it runs in a session tree of its own, never the caller's.
    with tempfile.TemporaryDirectory() as session:
        root = Path(session)
        env = {
            "PATH": os.environ["PATH"],
            "HOME": str(root / "home"),
            "XDG_CONFIG_HOME": str(root / "config"),
            "XDG_CACHE_HOME": str(root / "cache"),
            "XDG_STATE_HOME": str(root / "state"),
        }
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
            env=env,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.PIPE,
            text=True,
        )


def test_render_leaves_the_session_noctalia_state_alone(
    tmp_path: Path, monkeypatch
) -> None:
    live = tmp_path / "live"
    settings = live / "state/noctalia/settings.toml"
    settings.parent.mkdir(parents=True)
    # an older schema than the installed CLI writes: a run against this state
    # migrates it, as one did to the live shell's state on 2026-10-28
    settings.write_text("config_version = 12\n")
    for name, sub in (
        ("HOME", "home"),
        ("XDG_CONFIG_HOME", "config"),
        ("XDG_CACHE_HOME", "cache"),
        ("XDG_STATE_HOME", "state"),
    ):
        monkeypatch.setenv(name, str(live / sub))

    render(ROOT / "noctalia/templates/fzf.conf", tmp_path / "fzf.conf")

    assert settings.read_text() == "config_version = 12\n"


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
