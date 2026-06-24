import { buildSlotMap } from './slots.js';
import { themeCommands } from './theme.js';

export const SOCKET_PATH = `${process.env.XDG_RUNTIME_DIR ?? '/tmp'}/wsprofiled.sock`;

export class Daemon {
  constructor({ catalog, niri, noctalia, occupancy }) {
    this.catalog = catalog;
    this.niri = niri;
    this.noctalia = noctalia;
    this.occupancy = occupancy;
    this.slotMap = buildSlotMap(catalog);
    this.profileById = new Map(catalog.profiles.map((p) => [p.id, p]));
    this._focusSeq = 0;
    this._applyChain = Promise.resolve();
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
    if (!this.profileById.has(id)) return;
    await this.niri.focusWorkspace(id);
  }

  async new(id) {
    const profile = this.profileById.get(id);
    if (!profile) return;
    const free = this.occupancy.freeInstance(id, profile.instances);
    await this.niri.focusWorkspace(free ?? id);
  }
}
