// Pure projection of a validated catalog into the menu's view model.
// Mirrors src/kdl.js: shell-agnostic, no I/O.
export function viewModel(catalog) {
  return catalog.profiles.map((p) => ({
    id: p.id,
    label: p.label,
    icon: p.icon,
    ring: p.ring,
    border: p.border,
    instances: p.instances,
  }));
}
