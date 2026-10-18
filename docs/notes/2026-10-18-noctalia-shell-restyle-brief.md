# Noctalia shell restyle after glass cohesion: brief

2026-10-18. Handoff for `dots-6bfb8d` (restyle the bar, its pills and icons, the
launcher and the settings panel). Related: `dots-5b9b6d` (Dropbox tray icon,
scoped separately).

## 1. Problem

The bar, its widget pills and icons, the launcher, and the settings panel should
read as part of the same glass material as niri windows, kitty and neovim. That
is the last open dependency of the cross-project goal `ops-500adb` (one cohesive
glass material across niri, terminals, editor and shell).

## 2. Current behaviour and evidence

- `noctalia/config.toml`: `[bar.default]` sets `background_opacity = 0.93`; start
  `workspaces, cpu, ram`, center `active_window`, end `tray, battery,
  notifications, output_volume`, the Prism and wali-panel widgets, `clock`. No
  capsule keys, so pills are off (v5 default `capsule = false`). `[shell.panel]
  transparency_mode = "glass"`; `[accessibility] ui_scale = 1.05`; no `[shell]`
  table.
- The surface look is being delivered by niri-material, not here. Its spec
  `docs/specs/2026-10-16-noctalia-glass-cohesion-design.md` (in that repository;
  implemented 2026-10-17) moves the bar and panel surface family to the glass
  face's color and adds per-workspace project hue through a niri surface remap.
  `prism-301d9f` emits the rule; `material-1c4a82` rolls it out live, where the
  owner sets three settings-layer values: `[bar.default] background_opacity
  0.95`, `[shell.panel] transparency_mode solid`, `[shell] corner_radius_scale
  1.6`. Its out-of-scope list says this task "should take them from this design
  rather than choose its own". The owner's sheet judged three rows: the bar, the
  control center and the launcher.
- The remap moves only the family `surface`, `surface_container` and
  `outline_variant` (spec section 3). The v5 default pill fill is
  `surface_variant`, which is outside it, so pills turned on with the default fill
  would not follow the glass or the project hue.
- v5 styling knobs (the v5 source's `example.toml`, checkout of 2026-09-29;
  installed 5.3.0): per bar `capsule`, `capsule_fill`, `capsule_radius`,
  `capsule_opacity`, `capsule_border`, `scale`, `font_scale`; per widget `scale`,
  `font_scale`, `font_weight` and color; `[shell]` `font_family`,
  `corner_radius_scale`, `app_icon_colorize`/`app_icon_color`, shadow and
  animation; `[shell.panel]` `launcher_placement` (attached or floating) and
  `launcher_position`; `[shell.launcher]` `categories`, `show_icons`.
- Plugin widgets cannot color an icon button: `ui.button` has no color prop
  (`prism-ed35d4`; upstream draft PR noctalia-dev/noctalia#4320).
- The settings panel is built in and has no styling hooks beyond the shell-wide
  knobs above.

## 3. Constraints

- Surface colors, bar opacity, panel transparency and corner radius come from the
  glass cohesion design (`material-55380c`); this task does not choose them.
- `noctalia/config.toml` is live through the link from the main checkout; a
  worktree branch is not live until merged. The settings layer (`settings.toml`)
  is the owner's, and the material rollout writes there.
- Restyling the live bar is host-use and needs the owner's go-ahead at the time.
  niri-material has a nested-session sheet harness for comparisons.
- A change that needs Noctalia itself (settings panel styling, colored icon
  buttons) is an upstream contribution and goes through the owner.

## 4. Alternatives

- **A. Config-only restyle after the rollout (lean).** Once `material-1c4a82` is
  live, judge the bar with the owner and set pills, fonts, scales and launcher
  placement in `noctalia/config.toml`. Small and reversible. If pills go on, use a
  family color (`surface_container`) for `capsule_fill` so they follow the remap.
- **B. Prism-emitted pill styling.** Prism emits the pill fill, radius and border
  from the palette next to the remap rule. Only worth it if A's static values
  drift from the remapped surfaces as the wallpaper changes.
- **C. Upstream changes** for what config cannot reach, filed only for specific
  defects the owner names after A.

## 5. Unanswered questions

- After the rollout, what still reads as off: pills (on or off, fill, radius,
  border), icons (size, color), the launcher (attached or floating, icons,
  categories), the settings panel? The owner, on the live desktop or a
  nested-session sheet after `material-1c4a82`.
- Should pills carry the project hue (A with a family fill) or stay neutral? The
  owner, from the same look.
- Is the settings panel in scope at all, given it has no styling hooks of its
  own? The owner.

## 6. Proposed decomposition

- `dots-6bfb8d` depends on `material-1c4a82` (edge recorded 2026-10-18). When the
  rollout closes, the idea returns to the scope queue; the restyle pass starts from
  the owner's answers to section 5.
- `dots-5b9b6d` (todo) fixes the tray icon on its own through `[shell]
  app_icon_colorize`.
- No new research task: the knob inventory above answers what config can do.
