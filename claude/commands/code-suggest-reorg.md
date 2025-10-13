# Suggest Reorganization

Analyze project structure and propose improvements for better alignment and clarity.

## Analysis:

1. **Review current structure**
   - Examine codebase organization and naming conventions
   - Analyze `/doc/` structure (excluding `/doc/archive`)
   - Map relationships between components and documentation

2. **Identify core concepts**
   - Extract fundamental ideas and subsystems
   - Note misalignments between code structure and conceptual model
   - Find scattered or poorly encapsulated functionality

3. **Propose reorganization**
   
   **Logical improvements:**
   - Better naming for files, folders, and components
   - Clearer grouping of related functionality
   - Consistent conventions across the project
   
   **Structural improvements:**
   - Architectural changes to better achieve goals
   - Decoupling tightly bound components
   - Consolidating duplicate logic
   - Creating cleaner interfaces between subsystems

4. **Provide migration plan**
   - Order changes by impact and dependency
   - Highlight breaking changes
   - Suggest incremental steps if major restructuring needed

Output format: Prioritized list with rationale for each suggestion; print and save to a new file in
`/doc/reorg`.


Focus area: $ARGUMENTS (or comprehensive review if not specified)
