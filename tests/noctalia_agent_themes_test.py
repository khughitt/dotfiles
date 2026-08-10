#!/usr/bin/env python3

import json
import plistlib
import re
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
PLACEHOLDER = re.compile(r"{{colors\.([a-z0-9_]+)\.default\.hex}}")
NOCTALIA_ROLES = frozenset(
    """
    background error error_container inverse_on_surface inverse_primary
    inverse_surface on_background on_error on_error_container on_primary
    on_primary_container on_primary_fixed on_primary_fixed_variant on_secondary
    on_secondary_container on_secondary_fixed on_secondary_fixed_variant
    on_surface on_surface_variant on_tertiary on_tertiary_container
    on_tertiary_fixed on_tertiary_fixed_variant outline outline_variant primary
    primary_container primary_fixed primary_fixed_dim scrim secondary
    secondary_container secondary_fixed secondary_fixed_dim shadow surface
    surface_bright surface_container surface_container_high
    surface_container_highest surface_container_low surface_container_lowest
    surface_dim surface_variant tertiary tertiary_container tertiary_fixed
    tertiary_fixed_dim
    """.split()
)


def render(path: Path) -> bytes:
    text = path.read_text()
    roles = sorted(set(PLACEHOLDER.findall(text)))
    assert roles, f"no Noctalia placeholders in {path}"
    assert set(roles) <= NOCTALIA_ROLES, f"unknown Noctalia role in {path}"
    for index, role in enumerate(roles, 1):
        text = text.replace(
            f"{{{{colors.{role}.default.hex}}}}", f"#{index:06x}"
        )
    assert "{{" not in text, f"unresolved placeholder in {path}"
    return text.encode()


claude = json.loads(render(ROOT / "noctalia/templates/claude.json"))
assert claude["name"] == "Noctalia"
assert claude["base"] == "dark"
assert {
    "claude",
    "text",
    "inactive",
    "success",
    "error",
    "warning",
    "promptBorder",
    "planMode",
    "diffAdded",
    "diffRemoved",
} <= claude["overrides"].keys()

codex = plistlib.loads(render(ROOT / "noctalia/templates/codex.tmTheme"))
assert codex["name"] == "Noctalia"
assert codex["settings"][0]["settings"]["foreground"].startswith("#")
assert codex["settings"][0]["settings"]["background"].startswith("#")
assert any("comment" in entry.get("scope", "") for entry in codex["settings"])
assert any("keyword" in entry.get("scope", "") for entry in codex["settings"])
assert any("string" in entry.get("scope", "") for entry in codex["settings"])

print("OK noctalia agent themes")
