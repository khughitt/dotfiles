#!/usr/bin/env python3
"""
Patch agent skills to add user-invocable: true

This script iterates over skills in ~/.agents/skills/ and adds
user-invocable: true to SKILL.md frontmatter if not already present.

This makes skills appear in Crush's command palette (Ctrl+P).

Usage:
    ~/.config/crush/patch_skills_user_invocable.py
"""

import os
import re
from pathlib import Path


def parse_frontmatter(content: str) -> tuple[str, str]:
    """Extract YAML frontmatter and body from markdown file."""
    if not content.startswith("---"):
        return "", content
    
    parts = content.split("---", 2)
    if len(parts) < 3:
        return "", content
    
    frontmatter = parts[1].strip()
    body = parts[2]
    return frontmatter, body


def has_user_invocable(frontmatter: str) -> bool:
    """Check if frontmatter already has user-invocable field."""
    return re.search(r"^user-invocable\s*:", frontmatter, re.MULTILINE) is not None


def add_user_invocable(frontmatter: str) -> str:
    """Add user-invocable: true to frontmatter."""
    lines = frontmatter.split("\n")
    
    # Find the last field (before closing ---)
    # Insert user-invocable before the end
    lines.append("user-invocable: true")
    
    return "\n".join(lines)


def patch_skill_file(skill_path: Path) -> bool:
    """Patch a single SKILL.md file. Returns True if modified."""
    content = skill_path.read_text()
    frontmatter, body = parse_frontmatter(content)
    
    if not frontmatter:
        print(f"  ⚠ {skill_path}: no frontmatter found")
        return False
    
    if has_user_invocable(frontmatter):
        print(f"  ✓ {skill_path}: already has user-invocable")
        return False
    
    new_frontmatter = add_user_invocable(frontmatter)
    new_content = f"---\n{new_frontmatter}\n---{body}"
    
    skill_path.write_text(new_content)
    print(f"  + {skill_path}: added user-invocable: true")
    return True


def main():
    skills_dir = Path.home() / ".agents" / "skills"
    
    if not skills_dir.exists():
        print(f"Error: {skills_dir} does not exist")
        return 1
    
    print(f"Scanning {skills_dir}...\n")
    
    modified_count = 0
    skill_count = 0
    
    # Iterate over all subdirectories (skill packages)
    for skill_package in sorted(skills_dir.iterdir()):
        if not skill_package.is_dir():
            continue
        
        # Find all SKILL.md files in this package
        skill_files = list(skill_package.rglob("SKILL.md"))
        
        if not skill_files:
            continue
        
        print(f"Package: {skill_package.name}")
        for skill_file in skill_files:
            skill_count += 1
            if patch_skill_file(skill_file):
                modified_count += 1
        print()
    
    print(f"Processed {skill_count} skills, modified {modified_count}")
    return 0


if __name__ == "__main__":
    exit(main())
