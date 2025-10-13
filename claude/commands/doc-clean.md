# Clean and Reorganize Documentation

Consolidate and restructure project documentation to align with current codebase while preserving valuable unrealized ideas.

## Process:

1. **Analyze current state**
   - Review all markdown files in `/doc/` (_excluding_ `/doc/archive`)
   - Examine codebase to understand current system architecture
   - Map documentation against actual implementation
   - Identify: gaps, redundancies, outdated information, and unrealized ideas

2. **Categorize documentation**
   - **Active Reference**: Current system documentation, API refs, architecture notes
   - **Future Ideas**: Unimplemented features, design proposals, roadmap items
   - **Hybrid**: Docs with both implemented and unimplemented sections
   - **Obsolete**: Superseded designs, old migration guides, defunct features

3. **Archive truly obsolete content**
   - Create `/doc/archive/YYYY-MM-DD/` folder with today's date (`date -u +%Y-%m-%d`)
   - Move ONLY docs that are:
     - Related to removed/replaced features
     - Superseded by newer approaches (preserve the newer version)
     - Historical migration guides no longer relevant
   - Create `/doc/archive/YYYY-MM-DD/ARCHIVE_MANIFEST.md` listing what was archived and why

4. **Preserve and organize unrealized ideas**
   - Consolidate scattered feature ideas into `/doc/roadmap/` or `/doc/ideas/`
   - For hybrid docs with partial implementation:
     - Keep unimplemented parts prominent at the top
     - Move completed items to a "## Implementation History" section at bottom
     - Add status badges: `[PLANNED]`, `[IN-PROGRESS]`, `[COMPLETED]`
   - Link ideas to relevant system documentation where applicable

5. **Improve remaining documentation**
   - Ensure alignment between docs and actual codebase
   - Add "Last Verified" dates to reference documentation
   - Structure improvements:
     - `/doc/reference/` - Current system documentation
     - `/doc/roadmap/` - Future features and ideas (prioritized)
     - `/doc/guides/` - How-to and best practices
     - `/doc/architecture/` - System design and decisions
   - Update cross-references and create bidirectional links
   - Generate `/doc/README.md` with:
     - Documentation map/navigation
     - Quick links to key documents
     - Status of major feature ideas

6. **Quality checks**
   - Verify no valuable ideas were accidentally marked for archival
   - Ensure all unimplemented features are captured in roadmap/ideas
   - Check that current features have adequate documentation
   - Validate links and references still work

## Goals:
- Align documentation with actual codebase
- **Preserve all unrealized ideas and future plans**
- Consolidate scattered information into coherent narratives
- Improve discoverability through clear organization
- Maintain historical context where valuable
- Create clear separation between "what is" and "what could be"

## Safety Rules:
- Never archive documents containing unimplemented ideas without extracting them first
- When in doubt about a document's value, keep it and flag for review
- Preserve original timestamps and attribution where possible
- Maintain a clear audit trail of what was moved/changed

Focus areas: $ARGUMENTS (or reorganize all docs if not specified)

**Confirmation required before:**
- Moving any files to archive (show list with rationale)
- Consolidating multiple idea documents (show proposed merges)
- Deleting any content (prefer archiving when uncertain)
