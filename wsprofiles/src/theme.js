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
  if (t.mode) cmds.push(['darkMode', t.mode === 'dark' ? 'setDark' : 'setLight']);
  return cmds;
}
