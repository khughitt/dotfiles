import { homedir } from 'node:os';

export function expandHome(p) {
  if (!p) return p;
  if (p === '~') return homedir();
  if (p.startsWith('~/')) return homedir() + p.slice(1);
  return p;
}

export function themeCommands(profile) {
  const t = profile.theme;
  const cmds = [];
  if (t.wallpaper) cmds.push(['wallpaper', 'set', expandHome(t.wallpaper), 'all']);
  if (t.colorscheme) cmds.push(['colorScheme', 'set', t.colorscheme]);
  if (t.mode === 'dark') cmds.push(['darkMode', 'setDark']);
  else if (t.mode === 'light') cmds.push(['darkMode', 'setLight']);
  else if (t.mode) throw new Error(`theme.mode must be dark|light, got "${t.mode}"`);
  return cmds;
}
