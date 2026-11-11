# Desktop themes and palette promotion

Type: guide, data model, protocol; document types 1.

This reference describes the currently unversioned palette consumed by
[noctalia-glass-sync](../bin/noctalia-glass-sync), its publication protocol and
application readers. [Setup](setup.md) covers installation;
[development](development.md) covers source verification. No schema-version field
is currently required. Changing this contract requires updating its producers,
validators and readers together.

## Producers and ownership

Noctalia v5 renders [templates.toml](../noctalia/templates.toml) on palette changes.
Built-in entries cover GTK3/4, Qt, niri, Ghostty, kitty and btop; community entries
cover zathura, bat and yazi. User templates cover fzf, fastfetch, Glow, Neovim,
Claude, Codex, lsd, ohai and Prism. The registry names each source and output;
external ohai/Prism inputs remain owned by those projects. Setup links generated
output out to per-host state rather than committing it.

The Neovim template writes a candidate JSON palette and invokes the promoter.
The base defaults to `~/.cache/noctalia`; `NOCTALIA_GLASS_DIR` overrides that
base. The candidate is `nvim-palette.candidate.json` there and generations live
in its `nvim-glass` subdirectory. Application readers must resolve the same
publication location; overriding the promoter alone does not relocate readers.

Prism's entire config directory links to the host's tracked directory under
[prism](../prism/), including values and contexts. Saved profiles and wallpaper
deltas are tracked host input; active and scratch layers are runtime state.
Prism's niri sink renders `prism.kdl` and reloads the compositor. The open terminal
windows show material changes; sliders commit on release.

The Noctalia wallpaper hook passes `NOCTALIA_WALLPAPER_PATH` to
`prism context wallpaper`, then calls `walictl observe`. Untuned wallpapers have an
empty overlay; tuned ones restore their delta. Panel edits enter scratch and are
folded into the departing wallpaper's delta. Repeated connector notifications are
idempotent. Noctalia's timed automation is off; `wali-rotate.timer` runs
`walictl next`. Wali, Prism and Resource Pressure Alert own their v5 plugin code;
the older copied v4 plugin material is not the installed v5 implementation.

## Palette data model

The root is a JSON object. These required keys are strings in `#RRGGBB` form:

```text
primary primary_fixed_dim on_primary secondary secondary_fixed_dim
tertiary tertiary_fixed_dim error error_container surface on_surface
on_surface_variant on_background outline outline_variant surface_variant
```

The required `glass` object holds the following colors. Color comparisons are
case-insensitive. The seven registered tones must be pairwise distinct; duplication would give
different surfaces the same compositor treatment. Additional specific collisions
are forbidden as listed below.

| Field | Constraint | Opacity |
| --- | --- | ---: |
| chrome | hex color; registered | 0.35 |
| cursorline | hex color; registered | 0.30 |
| tab_off | hex color; registered | 0.30 |
| raised | hex color; registered; differs from outline | 0.40 |
| diff_added | fixed `#022800` | 0.55 |
| diff_removed | fixed `#3d0100` | 0.55 |
| selection | hex color; registered | 0.55 |
| tab_on | equals chrome | alias |
| tab_fill | equals tab_off | alias |
| selection_fg | hex color for selected foreground | opaque foreground |
| float | hex color; not a registered tone or root surface | opaque background |

Opacity is emitted on kitty transparent-background entries, not embedded in the
input color strings.
The promoter validates the full contract before generating output, including
`raised != outline`; reader validation and fallback are not substitutes for this
gate. Extra input keys do not replace required fields. The Neovim template and
committed default palette keep seven values distinct even when source colors
would otherwise coincide.

## Publication protocol

Participants are Noctalia/template producer, `noctalia-glass-sync`, the filesystem
and application readers. Generation directory names are internal publication IDs.

1. Read and validate the candidate. Reject missing, malformed or colliding fields
   before touching the active generation.
2. Stage a fresh version directory containing the original palette bytes,
   generated kitty configuration and generated OpenCode theme. Derive output from
   this one validated palette.
3. Publish `current` by atomically renaming a temporary symlink in the same
   directory. **This rename is the commit point.** Readers then resolve all three
   files through the same generation.
4. Consume the candidate and prune old generations, then notify eligible readers.
   `--no-signal` omits notification; it is not a dry run and still promotes files.

Neovim reads the promoted palette through its Lua reader and reloads on USR1.
A missing palette uses the committed default with one warning; malformed or
unreadable content is an error, not a quiet fallback. Kitty includes the promoted
configuration when present and otherwise retains its committed theme fallback.
OpenCode gets the generated theme file; its mapping is defined by `OPENCODE_MAP`
in the promoter, not by the retired design's version assumptions.

The promoter signals exact-name kitty and nvim processes with USR1. OpenCode USR2
is restricted to processes whose `/proc` name is `opencode`, whose real UID
matches the caller and which actually catch USR2; v2 serve processes without that
handler are skipped. These notifications are live host actions.

### Failure

Before the commit point, failure cleans the incomplete staged generation and
leaves the previous `current` active. Correct the candidate and retry; do not edit
published files in place. After the commit point, cleanup or notification can
fail while the new generation remains valid and active. Inspect `current` and
its three files before retrying or rolling back; a notification error is not
proof that promotion failed. Reload the affected reader deliberately after
reconciling state. Copy a known-good generation outside the pruned version directory before a
promotion if rollback is needed, and
publish a replacement link atomically rather than mixing files from generations.

For verification, use `bin/noctalia-glass-check` and relevant focused tests.
Source checks do not prove that the live compositor supports the material node,
that all readers received a signal, or that a host has rendered its first palette.
