import { slotName } from './slots.js';

export class OccupancyTracker {
  constructor() {
    this.nameById = new Map();
    this.wsByWindow = new Map();
  }

  apply(event) {
    if (event.WorkspacesChanged) {
      this.nameById.clear();
      for (const ws of event.WorkspacesChanged.workspaces) {
        if (ws.name) this.nameById.set(ws.id, ws.name);
      }
    } else if (event.WindowsChanged) {
      this.wsByWindow.clear();
      for (const w of event.WindowsChanged.windows) {
        if (w.workspace_id != null) this.wsByWindow.set(w.id, w.workspace_id);
      }
    } else if (event.WindowOpenedOrChanged) {
      const w = event.WindowOpenedOrChanged.window;
      if (w.workspace_id != null) this.wsByWindow.set(w.id, w.workspace_id);
      else this.wsByWindow.delete(w.id);
    } else if (event.WindowClosed) {
      this.wsByWindow.delete(event.WindowClosed.id);
    }
  }

  windowCount(workspaceName) {
    let count = 0;
    for (const wsId of this.wsByWindow.values()) {
      if (this.nameById.get(wsId) === workspaceName) count++;
    }
    return count;
  }

  freeInstance(profileId, instances) {
    for (let i = 2; i <= instances; i++) {
      const name = slotName(profileId, i);
      if (this.windowCount(name) === 0) return name;
    }
    return null;
  }
}
