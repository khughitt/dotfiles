# Clean and Reorganize Documentation

Consolidate and restructure project documentation to align with current codebase.

## Process:

1. **Analyze current state**
   - Review all markdown files in `/doc/` (_excluding_ `/doc/archive`)
   - Examine codebase to understand current system architecture
   - Identify gaps, redundancies, and outdated information

2. **Archive old/legacy docs**
   - Create `/doc/archive/YYYY-MM-DD/` folder with today's date (`date -u +%Y-%m-%d`)
   - Identify docs related to legacy features, completed implementation plans, and similar docs
     which are no longer needed, and move these to the archive folder
   - For partially implemented goals, remove the completed items to the a "# Completed" section at
     the bottom part of the file, so that remaining tasks are easy to find.

3. **Improve the quality of the remaining docs**
   - ensure that docs are well-aligned with the application codebase and vision
   - consolidate goals/ideas for the future into a single cohesive plan
   - consolidate redundant documentation
   - Organize by core concepts and subsystems
   - Structure guidelines:
     - Group related topics in subfolders
     - Break large docs into focused sub-topic files
     - Add "Related" sections linking core concepts
     - Create `/doc/overview.md` with high-level summary and navigation guide

## Goals:
- Align documentation with actual codebase
- Distill essential information and ideas
- Identify potential avenues for code improvement
- Remove outdated/redundant content
- Improve discoverability and navigation

Focus areas: $ARGUMENTS (or reorganize all docs if not specified)

Confirm before moving files to archive.
