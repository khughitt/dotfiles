# Update Documentation

Sync documentation with recent code changes and add forward-looking improvements.

## Tasks:

1. **Review current state of the codebase**

2. **Update existing docs**
   - Align descriptions with current implementation
   - Update code examples, API references, and configurations
   - Fix any outdated information or broken references

3. **Archive completed implementation plans and consolidate remaining ones**
   - Identify files which containing implementation plans for application features (these typically contain "phases 1 - N" and have checklists with specific steps)
   - mark implemented items as finished
   - move sections which have been entirely implemented towards the bottom of the file
   - if all of the goals of the file have been realized (or if we have decided to go a different route, stated in the code / other non-planning docs), move the files to the archive
     `/doc/archive/YYYY-MM-DD/` folder with today's date (`date -u +%Y-%m-%d`)
   - add remaining unimplemented items into a single "next-steps.md" file: @/doc/next-steps.md

4. **Enhance feature documentation**
   - Add "Next Steps" section to each feature doc:
     - Previously proposed improvements from docs/comments
     - New ideas that align with system goals
     - Priority and complexity indicators
   - Include rationale for why each step would add value

5. **Document gaps**
   - Create minimal docs for any undocumented recent changes
   - Flag areas needing more detailed documentation

Focus on: $ARGUMENTS (or all recent changes if not specified)
