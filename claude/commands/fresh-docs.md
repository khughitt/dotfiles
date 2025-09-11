# Clean and Reorganize Documentation

Consolidate and restructure project documentation to align with current codebase.

## Process:

1. **Analyze current state**
   - Review all markdown files in `/doc/` (_excluding_ `/doc/archive`)
   - Examine codebase to understand current system architecture
   - Identify gaps, redundancies, and outdated information

2. **Archive existing docs**
   - Create `/doc/archive/YYYY-MM-DD/` folder with today's date (`date -u +%Y-%m-%d`)
   - Move all current documentation to this archive folder
   - Preserve original structure for reference

3. **Create new documentation structure**
   - Write consolidated, concise docs reflecting current system state
   - Organize by core concepts and subsystems
   - Structure guidelines:
     - Group related topics in subfolders
     - Break large docs into focused sub-topic files
     - Add "Related" sections linking core concepts
     - Create `/doc/overview.md` with high-level summary and navigation guide

## Goals:
- Align documentation with actual codebase
- Distill essential information
- Identify potential avenues for code improvement
- Remove outdated/redundant content
- Improve discoverability and navigation

Focus areas: $ARGUMENTS (or reorganize all docs if not specified)
