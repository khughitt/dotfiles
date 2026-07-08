// True when `name` is a name the allocator could have assigned for `base`:
// the base itself, or `base-N` with N >= 2.
function ownsAllocatedForm(name, base) {
  if (name === base) return true;
  if (!name.startsWith(`${base}-`)) return false;
  const suffix = name.slice(base.length + 1);
  return /^\d+$/.test(suffix) && Number(suffix) >= 2;
}

// Pure reconciliation. See the design doc for the full algorithm.
//   states: [{ id, idx, currentName, empty, desiredBase }]
//   ownedNames: Map<wsId, name>  (names THIS daemon previously set)
// Returns { actions, ownedNames }. `ownedNames` carries ONLY observation-based
// updates (validation drops + confirmed matches). Ownership for emitted set/unset
// actions is applied by the caller AFTER the niri call succeeds (finding 1), so a
// failed call retries next pass instead of stranding a stale/foreign name.
export function reconcile(states, ownedNames) {
  const owned = new Map(ownedNames);

  // 1. Ownership validation: forget any workspace whose live name no longer
  //    matches what we set (external rename/unset/niri restart).
  for (const s of states) {
    if (owned.has(s.id) && owned.get(s.id) !== s.currentName) owned.delete(s.id);
  }

  // A workspace is writable — and therefore an allocation contender — only if we
  // would actually name it: it is unnamed, or we own it. Foreign named
  // workspaces are never contenders (finding 2); they only occupy `taken`.
  const writable = (s) => s.currentName === '' || owned.has(s.id);

  // 2. Names held by foreign (non-owned) workspaces are off-limits.
  const taken = new Set();
  for (const s of states) {
    if (s.currentName && !owned.has(s.id)) taken.add(s.currentName);
  }

  // 3. Allocate unique names for writable contenders, index-ordered for stable slotting.
  const ordered = [...states].sort((a, b) => a.idx - b.idx);
  const allocated = new Set(taken);
  const want = new Map(); // wsId -> allocated name

  // 3a. Contenders that already own a valid allocated form of their base (the
  //     base itself or base-N) keep that exact name, so a stable, already-unique
  //     assignment never churns just because idx order differs from the order
  //     suffixes were first handed out.
  for (const s of ordered) {
    if (!writable(s) || !s.desiredBase) continue;
    const cur = owned.get(s.id);
    if (cur !== undefined && ownsAllocatedForm(cur, s.desiredBase) && !taken.has(cur)) {
      want.set(s.id, cur);
      allocated.add(cur);
    }
  }
  // 3b. Every other contender gets base, or base-2/base-3… on collision.
  for (const s of ordered) {
    if (!writable(s) || !s.desiredBase || want.has(s.id)) continue;
    let name = s.desiredBase;
    let n = 2;
    while (allocated.has(name)) name = `${s.desiredBase}-${n++}`;
    want.set(s.id, name);
    allocated.add(name);
  }

  // 4. Decisions. set/unset actions carry wsId; ownership for them is applied by
  //    the caller on success. Only confirmed matches adopt ownership here.
  const actions = [];
  for (const s of states) {
    const target = want.get(s.id) ?? null;
    if (target == null) {
      if (s.empty && owned.has(s.id)) {
        actions.push({ type: 'unset', ref: s.currentName, wsId: s.id });
      }
      continue;
    }
    if (s.currentName === target) {
      owned.set(s.id, target); // observed match → adopt/confirm ownership now
    } else if (s.currentName === '') {
      actions.push({ type: 'set', ref: s.idx, name: target, wsId: s.id });
    } else if (owned.has(s.id)) {
      actions.push({ type: 'set', ref: s.currentName, name: target, wsId: s.id });
    }
    // else: non-empty foreign name → leave untouched
  }

  return { actions, ownedNames: owned };
}
