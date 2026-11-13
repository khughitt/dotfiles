# Code organization

Type: standard; document types 1. Code organization version 1 applies to every
project that declares `[code]` with `standard = 1` in its identity.toml, whether or
not it belongs to a family. A family whose family.toml declares `[code]` requires each
of its members to declare it.

<!-- Vendored from https://github.com/khughitt/ops (docs/code-organization.md); never edit the copy, see tools/README.md. -->

## Principles

1. The root holds manifests, guides, configuration and directories. No source files,
   apart from tool configuration a tool requires there (`build.rs`, `*.config.ts`).
   Member example: ops keeps only configuration and guides at the root.
2. One source tree per language, named for the project: a Python package, a crate, a
   JS/TS `src/`, a Go module. A repository with more than one language puts each under
   a language root (`python/`, `ts/`). Member example: tasks's `src/tasks/` package.
3. A subsystem is a directory with a one-line purpose at its top (package docstring,
   module doc comment, file header of its `index`). A filename prefix shared by three
   or more files is a missing directory: obs's eleven `session_logs_*.py` files are a
   `session_logs/` subsystem.
4. Deep modules, shallow interfaces: each subsystem exposes a small explicit surface
   and hides the rest. Public surface is declared, never implied (per-language
   mechanism below). Member example: hostkit's narrow subsystem exports.
5. Dependencies point one way: entry points depend on commands, commands on
   subsystems, subsystems on stores and adapters. No import cycles; a lower layer never
   imports a higher one. Member example: tasks CLI dispatching downward to commands and stores.
6. One entry point per command. It parses arguments and dispatches; it holds no
   domain logic. Commands live one group per file in a `commands/` (or `cli/`)
   directory once there is more than one, as tasks already does.
7. Names say what a thing is in the project's vocabulary. No `utils`, `helpers`,
   `misc`, `common` or `lib` grab-bag modules: name the concept the code serves.
   Member example: naming stores and adapters after their roles.
8. Composition over inheritance; explicit failure over defensive fallback (from the
   user's core rules, stated here because module boundaries are where they bite).
   Member example: failing explicitly on missing configuration rather than silently defaulting.
9. `bin/` holds what users or other projects run. A `bin/` script is self-contained
   (standard library and vendored helpers only). When two scripts share code, or one
   needs a helper module, the shared code becomes a package and the scripts become
   thin launchers. A script that is itself vendored as a single file (ops's `tt`,
   `ops-check`, `ops-docs`, `cli_surface.py`) stays one self-contained file by design.
10. Three homes, never mixed. `vendor/<source>/` holds what is copied from elsewhere
    and never edited here, one directory per source: `vendor/ops/` for everything
    ops's tooling distributes (vendored tools, adopted contracts, the guide, its
    README, and the family file whichever home publishes it), submodules and other
    third-party copies under their own names (lore's `vendor/superpowers`).
    `scripts/` holds the repository's own maintenance scripts: build, gates, probes,
    benchmarks, release, setup. `bin/` holds what users or other projects run.
    Application code and tests live in neither `scripts/` nor `vendor/`, and no
    repository keeps a `tools/` directory.
    Until the relocation task lands, ops's tooling still writes its copies to `tools/`.
11. Tests live in `tests/` (one name, every language), mirroring the source tree's
    paths, except where the language's idiom puts unit tests beside the code (Go
    `_test.go`, Rust `#[cfg(test)]` modules). Fixtures live in `tests/fixtures/`.
    Member example: ops's `tests/` mirroring its test suites.
12. Moving code updates every caller in the same change, including callers outside
    the repository (systemd units, skills, hooks, other projects' guides), with no
    re-export shims left behind. Member example: moving a command updates callers
    without leaving re-export shims.

## Layout by language

| | Package root | Entry point | Public vs internal | Tests | File names |
| --- | --- | --- | --- | --- | --- |
| Python, standard library, uninstalled | `src/<pkg>/` with `__init__.py` and `__main__.py` | `bin/<name>`: a launcher that puts `src/` on `sys.path` and calls `<pkg>.cli:main` | `__all__` in each package's `__init__.py`; leading underscore for internal modules | `tests/`; the project's test recipes put `src/` on the import path (`PYTHONPATH=src`, ahead of any test path they already set), which serves `unittest` and pytest alike; no new test runner | `snake_case.py` |
| Python, uv-managed | `src/<pkg>/` | `[project.scripts]` | as above | `tests/` | as above |
| JS/TS | `src/`, subsystem dirs with an `index` | `bin/<name>` launcher declared in package.json `bin`, calling `src/cli` | the `index` of each subsystem exports its surface; package.json `exports` for anything another project imports | `tests/` | `kebab-case` |
| Rust | `src/main.rs` thin, `src/lib.rs` (when other crates or tests need the code) | `src/main.rs` | `pub` only for the surface, `pub(crate)` otherwise; subsystem as `src/<sub>/mod.rs` or `src/<sub>.rs` + `src/<sub>/` | integration tests in `tests/`, unit tests inline | `snake_case.rs` |
| Go | module root | `cmd/<name>/main.go` | `internal/<pkg>` for everything not imported elsewhere | `_test.go` beside code | `snake_case.go` |

The root-source check matches by extension only (`.py .js .mjs .cjs .ts .tsx .rs .go .sh`), exempting `build.rs`, `conftest.py` and `*.config.{js,mjs,cjs,ts}`.

## More than one language

A repository with more than one language puts each under a language root (`python/`, `ts/`). Families may add stricter rules through their `[code]` note (for example, verifiably requiring language roots even for single-language members).

## What binds existing code

The repository-layout rules (principles 1, 2, 3, 6, 10, 11 and the per-language directory columns) bind every project that declares `[code]` now; departures receive a tracked conformance piece or a recorded deviation. The in-module rules (principle 4's declared surface, principle 9's self-contained scripts, naming rule 7, and the per-language public-vs-internal column) bind new code and code touched by a change: adding to a subsystem's surface declares that surface (`index` or `__all__`), and sharing script code moves it into a package. Untouched files are not flagged.

## Deviations

A repository departing from an unchecked rule records it in one line under its `AGENTS.md` Layout section with the reason (for example, a static site served as-is). A departure from the checked root-source rule is declared in `.ops-check.toml` under `root_sources_allowed`, with a comment giving the reason.

## Checklist

1. Does new code sit in an existing subsystem or a new named directory?
2. Is new public surface explicitly declared (`__all__`, `index`, or `pub`)?
3. Do all dependencies point downward (no upward imports or cyclic dependencies)?
4. Are all modules named for the concepts they serve (no `utils`, `helpers`, `common`, or `misc`)?
5. Does any moved code update all callers atomically without leaving re-export shims?
6. Is each script in `bin/` self-contained without importing a sibling script?
7. Do tests live in `tests/` mirroring the source layout?

## Versions

- **1 — 2026-11-08:** First version (ops-8d753d).
