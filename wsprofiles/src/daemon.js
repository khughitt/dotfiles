import { buildSlotMap } from './slots.js';
import { ID_RE } from './catalog.js';
import { themeCommands } from './theme.js';

export const SOCKET_PATH = `${process.env.XDG_RUNTIME_DIR ?? '/tmp'}/wsprofiled.sock`;
const CONTROL_USAGE = 'usage: open|new <profile-id>';

export function parseControlLine(line) {
  const match = /^(open|new) ([^\s]+)$/.exec(line);
  if (!match) throw new Error(CONTROL_USAGE);
  const [, cmd, id] = match;
  if (!ID_RE.test(id) || /-\d+$/.test(id)) throw new Error(CONTROL_USAGE);
  return { cmd, id };
}

export class Daemon {
  constructor({ catalog, niri, noctalia, occupancy }) {
    this.niri = niri;
    this.noctalia = noctalia;
    this.occupancy = occupancy;
    this.updateCatalog(catalog);
    this._focusSeq = 0;
    this._applyChain = Promise.resolve();
  }

  updateCatalog(catalog) {
    this.catalog = catalog;
    this.slotMap = buildSlotMap(catalog);
    this.profileById = new Map(catalog.profiles.map((p) => [p.id, p]));
  }

  onFocus(workspaceName) {
    const slot = this.slotMap.get(workspaceName);
    if (!slot) return this._applyChain;
    const seq = ++this._focusSeq;
    const profile = this.profileById.get(slot.profileId);

    this._applyChain = this._applyChain
      .then(async () => {
        if (seq !== this._focusSeq) return;
        await this.noctalia.runCommands(themeCommands(profile));
      })
      .catch((e) => console.error('wsprofiled: theme apply failed:', e.message));
    return this._applyChain;
  }

  async open(id) {
    if (!this.profileById.has(id)) throw new Error(`unknown profile id: ${id}`);
    await this.niri.focusWorkspace(id);
  }

  async new(id) {
    const profile = this.profileById.get(id);
    if (!profile) throw new Error(`unknown profile id: ${id}`);
    const free = this.occupancy.freeInstance(id, profile.instances);
    await this.niri.focusWorkspace(free ?? id);
  }
}
