import { readFileSync } from 'node:fs';
import { parse as parseYaml } from 'yaml';

export const ID_RE = /^[a-z][a-z0-9-]*$/;
export const COLOR_RE = /^#([0-9a-fA-F]{3,4}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/;

function isMapping(value) {
  return value != null && typeof value === 'object' && !Array.isArray(value);
}

function validateProfile(raw, seen) {
  if (!isMapping(raw)) throw new Error('profile entry must be a mapping');
  if (typeof raw.id !== 'string') throw new Error('profile is missing a string id');
  if (!ID_RE.test(raw.id)) throw new Error(`id "${raw.id}" must match ${ID_RE}`);
  if (/-\d+$/.test(raw.id)) throw new Error(`id "${raw.id}" must not end in -<digits>`);
  if (seen.has(raw.id)) throw new Error(`duplicate id "${raw.id}"`);
  seen.add(raw.id);
  if (typeof raw.ring !== 'string' || !COLOR_RE.test(raw.ring))
    throw new Error(`profile "${raw.id}" ring must be a hex color like #rrggbb`);
  if (raw.border != null && !COLOR_RE.test(raw.border))
    throw new Error(`profile "${raw.id}" border must be a hex color like #rrggbb`);
  const t = raw.theme === undefined ? {} : raw.theme;
  if (!isMapping(t)) throw new Error(`profile "${raw.id}" theme must be a mapping`);
  if (t.mode != null && !['dark', 'light'].includes(t.mode))
    throw new Error(`profile "${raw.id}" theme.mode must be dark|light`);
  const instances = raw.instances ?? 1;
  if (!Number.isInteger(instances) || instances < 1)
    throw new Error(`profile "${raw.id}" instances must be a positive integer`);
  return {
    id: raw.id,
    label: raw.label ?? raw.id,
    instances,
    ring: raw.ring,
    border: raw.border ?? null,
    icon: raw.icon ?? '',
    theme: {
      colorscheme: t.colorscheme ?? null,
      wallpaper: t.wallpaper ?? null,
      mode: t.mode ?? null,
    },
  };
}

export function parseCatalog(text) {
  const doc = parseYaml(text);
  if (!doc || !Array.isArray(doc.profiles))
    throw new Error('catalog must have a top-level "profiles" list');
  const seen = new Set();
  return { profiles: doc.profiles.map((p) => validateProfile(p, seen)) };
}

export function loadCatalog(path) {
  return parseCatalog(readFileSync(path, 'utf8'));
}
