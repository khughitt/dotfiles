import { homedir } from 'node:os';

export function expandHome(p) {
  if (!p) return p;
  if (p === '~') return homedir();
  if (p.startsWith('~/')) return homedir() + p.slice(1);
  return p;
}

export function themeState(profile) {
  const t = profile.theme;
  if (t.mode && !['dark', 'light'].includes(t.mode))
    throw new Error(`theme.mode must be dark|light, got "${t.mode}"`);
  return {
    wallpaper: t.wallpaper ? expandHome(t.wallpaper) : null,
    colorscheme: t.colorscheme ?? null,
    mode: t.mode ?? null,
  };
}

export function themeCommands(profile, previous = null) {
  const t = themeState(profile);
  const cmds = [];
  if (t.wallpaper) cmds.push(['wallpaper', 'set', t.wallpaper, 'all']);
  if (t.colorscheme && t.colorscheme !== previous?.colorscheme)
    cmds.push(['colorScheme', 'set', t.colorscheme]);
  if (t.mode === 'dark' && t.mode !== previous?.mode) cmds.push(['darkMode', 'setDark']);
  else if (t.mode === 'light' && t.mode !== previous?.mode) cmds.push(['darkMode', 'setLight']);
  return cmds;
}
