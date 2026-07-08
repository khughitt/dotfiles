export class WorkspaceState {
  constructor() {
    this.windowsById = new Map();      // id -> { id, appId, pid, title, wsId }
    this.workspaces = new Map();       // id -> { id, idx, name }
    this.activeWindowByWs = new Map(); // wsId -> windowId
  }

  apply(ev) {
    if (ev.WorkspacesChanged) {
      this.workspaces.clear();
      for (const w of ev.WorkspacesChanged.workspaces) {
        this.workspaces.set(w.id, { id: w.id, idx: w.idx, name: w.name ?? '' });
      }
    } else if (ev.WindowsChanged) {
      this.windowsById.clear();
      this.activeWindowByWs.clear();
      for (const w of ev.WindowsChanged.windows) this._upsert(w);
    } else if (ev.WindowOpenedOrChanged) {
      this._upsert(ev.WindowOpenedOrChanged.window);
    } else if (ev.WindowClosed) {
      this.windowsById.delete(ev.WindowClosed.id);
    } else if (ev.WorkspaceActiveWindowChanged) {
      const { workspace_id, active_window_id } = ev.WorkspaceActiveWindowChanged;
      if (active_window_id == null) this.activeWindowByWs.delete(workspace_id);
      else this.activeWindowByWs.set(workspace_id, active_window_id);
    }
  }

  _upsert(w) {
    if (w.workspace_id == null) { this.windowsById.delete(w.id); return; }
    this.windowsById.set(w.id, {
      id: w.id,
      appId: w.app_id ?? '',
      pid: w.pid ?? null,
      title: w.title ?? '',
      wsId: w.workspace_id,
    });
    if (w.is_focused) this.activeWindowByWs.set(w.workspace_id, w.id);
  }

  _windowsOf(wsId) {
    const out = [];
    for (const win of this.windowsById.values()) if (win.wsId === wsId) out.push(win);
    out.sort((a, b) => a.id - b.id);
    return out;
  }

  namingWindow(wsId) {
    const wins = this._windowsOf(wsId);
    if (wins.length === 0) return null;
    const activeId = this.activeWindowByWs.get(wsId);
    if (activeId != null) {
      const active = wins.find((w) => w.id === activeId);
      if (active) return active;
    }
    return wins[0];
  }
}
