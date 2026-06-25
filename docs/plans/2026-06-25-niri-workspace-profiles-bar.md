# Niri Workspace Profiles Bar Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a noctalia v4 horizontal-bar plugin that replaces the core Workspace widget with a per-profile colored workspace strip backed by `~/.config/niri/wsprofiles.json`.

**Architecture:** The plugin lives under `~/d/dotfiles/noctalia/plugins/niri-workspace-profiles/` and is symlinked into noctalia's user plugin directory. Pure classic-QML-JS logic handles profile parsing, workspace filtering, profile resolution, glyph selection, and foreground contrast; `BarWidget.qml` handles FileView watching, CompositorService snapshots, horizontal QML rendering, tooltips, and click-to-focus. The daemon, niri config, and Phase 2 selector are read-only inputs for this phase; left/right vertical bars should keep noctalia's core `Workspace` widget in v1.

**Tech Stack:** Quickshell QML, noctalia v4 plugin API, classic QML JavaScript, Node `node:test` with `node:vm` loader, niri `CompositorService`.

---

## File Structure

- Create `~/d/dotfiles/noctalia/plugins/niri-workspace-profiles/manifest.json` — noctalia plugin manifest registering `plugin:niri-workspace-profiles`.
- Create `~/d/dotfiles/noctalia/plugins/niri-workspace-profiles/Main.qml` — minimal plugin main object.
- Create `~/d/dotfiles/noctalia/plugins/niri-workspace-profiles/logic.js` — pure classic-QML-JS logic shared by QML and Node tests.
- Create `~/d/dotfiles/noctalia/plugins/niri-workspace-profiles/logic.test.mjs` — Node tests for `logic.js`.
- Create `~/d/dotfiles/noctalia/plugins/niri-workspace-profiles/BarWidget.qml` — horizontal bar strip UI, FileView watcher, workspace snapshot bridge, and click handling.
- Local artifact, not committed: `~/.config/noctalia/plugins/niri-workspace-profiles` symlink to `~/d/dotfiles/noctalia/plugins/niri-workspace-profiles`.

## Implementation Tasks

### Task 1: Pure Bar Logic

**Files:**
- Create: `noctalia/plugins/niri-workspace-profiles/logic.js`
- Create: `noctalia/plugins/niri-workspace-profiles/logic.test.mjs`

- [ ] **Step 1: Create the plugin directory**

Run:

```bash
rtk mkdir -p ~/d/dotfiles/noctalia/plugins/niri-workspace-profiles
```

Expected: `~/d/dotfiles/noctalia/plugins/niri-workspace-profiles/` exists.

- [ ] **Step 2: Write the failing tests**

Create `~/d/dotfiles/noctalia/plugins/niri-workspace-profiles/logic.test.mjs`:

```javascript
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import vm from 'node:vm';

function loadLogic() {
  const path = fileURLToPath(new URL('./logic.js', import.meta.url));
  const src = readFileSync(path, 'utf8').replace(/^\s*\.pragma\s+library\s*$/m, '');
  const context = {};
  vm.runInNewContext(src, context);
  return context;
}

const Logic = loadLogic();

function plain(value) {
  return value === null ? null : JSON.parse(JSON.stringify(value));
}

const profiles = [
  { id: 'ember', label: 'Ember - client-api', icon: '', ring: '#ff7a45' },
  { id: 'tide', label: 'Tide - infra', icon: 'T', ring: '#3aa6ff' },
  { id: 'api2', label: 'API Two', icon: 'A', ring: '#222222' },
];

const workspaces = [
  { id: 1, idx: 1, name: 'ember', output: 'DP-1', isFocused: true, isOccupied: true, isUrgent: false },
  { id: 2, idx: 2, name: 'tide-2', output: 'DP-1', isFocused: false, isOccupied: false, isUrgent: true },
  { id: 3, idx: 3, name: 'scratchpad', output: 'HDMI-A-1', isFocused: false, isOccupied: true, isUrgent: false },
];

test('parseProfiles: valid profile array returns profiles and no error', () => {
  const result = Logic.parseProfiles(JSON.stringify(profiles));
  assert.equal(result.error, null);
  assert.deepEqual(plain(result.profiles), profiles);
});

test('parseProfiles: invalid inputs return empty profiles and an error', () => {
  for (const text of [
    '',
    '{ not json',
    '{}',
    JSON.stringify([{ id: 'ember' }]),
    JSON.stringify([{ id: 'bad', label: 'Bad', ring: 'nothex' }]),
  ]) {
    const result = Logic.parseProfiles(text);
    assert.deepEqual(plain(result.profiles), []);
    assert.equal(typeof result.error, 'string');
    assert.ok(result.error.length > 0);
  }
});

test('resolveProfile: exact id and instance suffix resolution', () => {
  assert.equal(Logic.resolveProfile('ember', profiles).id, 'ember');
  assert.equal(Logic.resolveProfile('tide-2', profiles).id, 'tide');
  assert.equal(Logic.resolveProfile('tide-3', profiles).id, 'tide');
  assert.equal(Logic.resolveProfile('api2', profiles).id, 'api2');
  assert.equal(Logic.resolveProfile('scratchpad', profiles), null);
});

test('filterWorkspaces: globalWorkspaces keeps all outputs', () => {
  const result = Logic.filterWorkspaces(workspaces, {
    screenName: 'DP-1',
    focusedOutput: 'DP-1',
    globalWorkspaces: true,
    followFocusedScreen: false,
    hideUnoccupied: false,
  });
  assert.deepEqual(result.map(ws => ws.name), ['ember', 'tide-2', 'scratchpad']);
});

test('filterWorkspaces: follows current screen with case-insensitive output matching', () => {
  const result = Logic.filterWorkspaces(workspaces, {
    screenName: 'dp-1',
    focusedOutput: 'HDMI-A-1',
    globalWorkspaces: false,
    followFocusedScreen: false,
    hideUnoccupied: false,
  });
  assert.deepEqual(result.map(ws => ws.name), ['ember', 'tide-2']);
});

test('filterWorkspaces: follows focused screen and can hide unoccupied workspaces', () => {
  const result = Logic.filterWorkspaces(workspaces, {
    screenName: 'DP-1',
    focusedOutput: 'dp-1',
    globalWorkspaces: false,
    followFocusedScreen: true,
    hideUnoccupied: true,
  });
  assert.deepEqual(result.map(ws => ws.name), ['ember']);
});

test('filterWorkspaces: hideUnoccupied keeps the focused workspace even when empty', () => {
  const result = Logic.filterWorkspaces([
    { id: 4, idx: 4, name: 'empty-focused', output: 'DP-1', isFocused: true, isOccupied: false },
    { id: 5, idx: 5, name: 'empty-other', output: 'DP-1', isFocused: false, isOccupied: false },
  ], {
    screenName: 'DP-1',
    focusedOutput: 'DP-1',
    globalWorkspaces: false,
    followFocusedScreen: false,
    hideUnoccupied: true,
  });
  assert.deepEqual(result.map(ws => ws.name), ['empty-focused']);
});

test('buildCells: maps profiled and unprofiled workspaces in order', () => {
  const result = Logic.buildCells(workspaces, profiles);
  assert.deepEqual(plain(result), [
    {
      id: 1,
      idx: 1,
      name: 'ember',
      output: 'DP-1',
      hasProfile: true,
      ring: '#ff7a45',
      glyph: 'E',
      label: 'Ember - client-api',
      isFocused: true,
      isOccupied: true,
      isUrgent: false,
    },
    {
      id: 2,
      idx: 2,
      name: 'tide-2',
      output: 'DP-1',
      hasProfile: true,
      ring: '#3aa6ff',
      glyph: 'T',
      label: 'Tide - infra',
      isFocused: false,
      isOccupied: false,
      isUrgent: true,
    },
    {
      id: 3,
      idx: 3,
      name: 'scratchpad',
      output: 'HDMI-A-1',
      hasProfile: false,
      ring: null,
      glyph: '3',
      label: 'scratchpad',
      isFocused: false,
      isOccupied: true,
      isUrgent: false,
    },
  ]);
});

test('buildCells: unprofiled workspace without idx uses dot glyph', () => {
  const result = Logic.buildCells([{ id: 9, name: 'scratchpad', output: 'DP-1' }], []);
  assert.equal(result[0].glyph, '.');
  assert.equal(result[0].hasProfile, false);
});

test('buildCells: empty workspaces returns empty cells', () => {
  assert.deepEqual(plain(Logic.buildCells([], profiles)), []);
});

test('pickForeground: returns readable black or white foreground', () => {
  assert.equal(Logic.pickForeground('#ffffff'), '#000000');
  assert.equal(Logic.pickForeground('#ff7a45'), '#000000');
  assert.equal(Logic.pickForeground('#000000'), '#ffffff');
  assert.equal(Logic.pickForeground('#1e1e2e'), '#ffffff');
  assert.equal(Logic.pickForeground('#fff'), '#000000');
  assert.equal(Logic.pickForeground('#777777'), '#000000');
  assert.equal(Logic.pickForeground('#808080'), '#000000');
  assert.equal(Logic.pickForeground(''), '#ffffff');
  assert.equal(Logic.pickForeground('nothex'), '#ffffff');
  assert.equal(Logic.pickForeground(undefined), '#ffffff');
});

test('parseHexColor: parses shorthand and long hex colors', () => {
  assert.deepEqual(plain(Logic.parseHexColor('#fff')), { r: 255, g: 255, b: 255 });
  assert.deepEqual(plain(Logic.parseHexColor('#112233')), { r: 17, g: 34, b: 51 });
});

test('parseHexColor: invalid values return null', () => {
  assert.equal(Logic.parseHexColor(''), null);
  assert.equal(Logic.parseHexColor('nothex'), null);
  assert.equal(Logic.parseHexColor('#12'), null);
  assert.equal(Logic.parseHexColor(undefined), null);
});

test('channelLuminance: maps black and white endpoints', () => {
  assert.equal(Logic.channelLuminance(0), 0);
  assert.equal(Logic.channelLuminance(255), 1);
});
```

- [ ] **Step 3: Run the tests to verify they fail**

Run:

```bash
rtk node --test ~/d/dotfiles/noctalia/plugins/niri-workspace-profiles/logic.test.mjs
```

Expected: FAIL with `ENOENT` for `logic.js`, or FAIL because the tested functions are not defined.

- [ ] **Step 4: Implement `logic.js`**

Create `~/d/dotfiles/noctalia/plugins/niri-workspace-profiles/logic.js`:

```javascript
.pragma library

function parseProfiles(text) {
  if (typeof text !== 'string' || text.trim() === '') {
    return { profiles: [], error: 'empty' };
  }

  var data;
  try {
    data = JSON.parse(text);
  } catch (e) {
    return { profiles: [], error: 'invalid json' };
  }

  if (!Array.isArray(data)) {
    return { profiles: [], error: 'not an array' };
  }

  for (var i = 0; i < data.length; i++) {
    var p = data[i];
    if (!p || typeof p !== 'object'
        || typeof p.id !== 'string'
        || typeof p.label !== 'string'
        || typeof p.ring !== 'string') {
      return { profiles: [], error: 'bad profile shape at index ' + i };
    }
    if (!parseHexColor(p.ring)) {
      return { profiles: [], error: 'bad profile ring at index ' + i };
    }
  }

  return { profiles: data, error: null };
}

function normalizeText(value) {
  return String(value || '').toLowerCase();
}

function resolveProfile(name, profiles) {
  if (typeof name !== 'string') {
    return null;
  }

  for (var i = 0; i < profiles.length; i++) {
    if (profiles[i].id === name) {
      return profiles[i];
    }
  }

  var base = name.replace(/-\d+$/, '');
  if (base === name) {
    return null;
  }

  for (var j = 0; j < profiles.length; j++) {
    if (profiles[j].id === base) {
      return profiles[j];
    }
  }

  return null;
}

function filterWorkspaces(workspaces, opts) {
  var result = [];
  var screenName = normalizeText(opts && opts.screenName);
  var focusedOutput = normalizeText(opts && opts.focusedOutput);
  var globalWorkspaces = !!(opts && opts.globalWorkspaces);
  var followFocusedScreen = !!(opts && opts.followFocusedScreen);
  var hideUnoccupied = !!(opts && opts.hideUnoccupied);

  for (var i = 0; i < workspaces.length; i++) {
    var ws = workspaces[i];
    var output = normalizeText(ws && ws.output);
    var matchesScreen = globalWorkspaces
      || (followFocusedScreen && output === focusedOutput)
      || (!followFocusedScreen && output === screenName);

    if (!matchesScreen) {
      continue;
    }

    if (hideUnoccupied && !ws.isOccupied && !ws.isFocused) {
      continue;
    }

    result.push(ws);
  }

  return result;
}

function firstTextCharacter(text, fallback) {
  var value = String(text || '');
  if (value.length === 0) {
    return fallback;
  }
  return value.charAt(0).toUpperCase();
}

function workspaceGlyph(ws) {
  if (ws && ws.idx !== undefined && ws.idx !== null) {
    return String(ws.idx);
  }
  return '.';
}

function buildCells(workspaces, profiles) {
  var result = [];

  for (var i = 0; i < workspaces.length; i++) {
    var ws = workspaces[i];
    var profile = resolveProfile(ws.name, profiles);
    var label = profile ? profile.label : (ws.name || String(ws.idx || ''));
    var icon = profile && typeof profile.icon === 'string' ? profile.icon : '';

    result.push({
      id: ws.id,
      idx: ws.idx,
      name: ws.name || '',
      output: ws.output || '',
      hasProfile: !!profile,
      ring: profile ? profile.ring : null,
      glyph: profile ? (icon.length > 0 ? icon : firstTextCharacter(label, workspaceGlyph(ws))) : workspaceGlyph(ws),
      label: label,
      isFocused: !!ws.isFocused,
      isOccupied: !!ws.isOccupied,
      isUrgent: !!ws.isUrgent,
    });
  }

  return result;
}

function parseHexColor(hex) {
  if (typeof hex !== 'string') {
    return null;
  }

  var value = hex.trim();
  var match3 = /^#([0-9a-fA-F]{3})$/.exec(value);
  if (match3) {
    return {
      r: parseInt(match3[1].charAt(0) + match3[1].charAt(0), 16),
      g: parseInt(match3[1].charAt(1) + match3[1].charAt(1), 16),
      b: parseInt(match3[1].charAt(2) + match3[1].charAt(2), 16),
    };
  }

  var match6 = /^#([0-9a-fA-F]{6})$/.exec(value);
  if (!match6) {
    return null;
  }

  return {
    r: parseInt(match6[1].slice(0, 2), 16),
    g: parseInt(match6[1].slice(2, 4), 16),
    b: parseInt(match6[1].slice(4, 6), 16),
  };
}

function channelLuminance(value) {
  var normalized = value / 255;
  if (normalized <= 0.03928) {
    return normalized / 12.92;
  }
  return Math.pow((normalized + 0.055) / 1.055, 2.4);
}

function relativeLuminance(rgb) {
  return 0.2126 * channelLuminance(rgb.r)
    + 0.7152 * channelLuminance(rgb.g)
    + 0.0722 * channelLuminance(rgb.b);
}

function contrastRatio(lighter, darker) {
  return (lighter + 0.05) / (darker + 0.05);
}

function pickForeground(ring) {
  var rgb = parseHexColor(ring);
  if (!rgb) {
    return '#ffffff';
  }

  var luminance = relativeLuminance(rgb);
  var blackContrast = contrastRatio(luminance, 0);
  var whiteContrast = contrastRatio(1, luminance);
  return blackContrast > whiteContrast ? '#000000' : '#ffffff';
}
```

- [ ] **Step 5: Run the tests to verify they pass**

Run:

```bash
rtk node --test ~/d/dotfiles/noctalia/plugins/niri-workspace-profiles/logic.test.mjs
```

Expected: PASS, with all `logic.test.mjs` tests passing.

- [ ] **Step 6: Commit**

Run:

```bash
rtk git add noctalia/plugins/niri-workspace-profiles/logic.js noctalia/plugins/niri-workspace-profiles/logic.test.mjs
rtk git commit -m "feat(noctalia): workspace profile bar logic"
```

Expected: commit succeeds.

### Task 2: Plugin Manifest and Main Entry

**Files:**
- Create: `noctalia/plugins/niri-workspace-profiles/manifest.json`
- Create: `noctalia/plugins/niri-workspace-profiles/Main.qml`

- [ ] **Step 1: Create `manifest.json`**

Create `~/d/dotfiles/noctalia/plugins/niri-workspace-profiles/manifest.json`:

```json
{
  "id": "niri-workspace-profiles",
  "name": "Niri Workspace Profiles",
  "version": "1.0.0",
  "minNoctaliaVersion": "4.7.0",
  "author": "Keith Hughitt",
  "license": "MIT",
  "description": "Horizontal niri workspace strip showing per-profile icon, color, and label.",
  "tags": ["Bar", "Niri"],
  "entryPoints": {
    "main": "Main.qml",
    "barWidget": "BarWidget.qml"
  },
  "dependencies": {
    "plugins": []
  },
  "metadata": {
    "defaultSettings": {
      "followFocusedScreen": false,
      "hideUnoccupied": false
    }
  }
}
```

- [ ] **Step 2: Create `Main.qml`**

Create `~/d/dotfiles/noctalia/plugins/niri-workspace-profiles/Main.qml`:

```qml
import QtQuick

QtObject {
  id: root

  property var pluginApi: null
}
```

- [ ] **Step 3: Validate the manifest JSON**

Run:

```bash
rtk node -e "const fs = require('fs'); JSON.parse(fs.readFileSync('noctalia/plugins/niri-workspace-profiles/manifest.json', 'utf8'));"
```

Expected: command exits `0` with no output.

- [ ] **Step 4: Commit**

Run:

```bash
rtk git add noctalia/plugins/niri-workspace-profiles/manifest.json noctalia/plugins/niri-workspace-profiles/Main.qml
rtk git commit -m "feat(noctalia): register workspace profile bar plugin"
```

Expected: commit succeeds.

### Task 3: Bar Widget QML

**Files:**
- Create: `noctalia/plugins/niri-workspace-profiles/BarWidget.qml`

- [ ] **Step 1: Create `BarWidget.qml`**

Create `~/d/dotfiles/noctalia/plugins/niri-workspace-profiles/BarWidget.qml`:

```qml
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.Compositor
import qs.Services.UI
import qs.Widgets
import "logic.js" as Logic

Item {
  id: root

  property ShellScreen screen
  property var pluginApi: null

  property string widgetId: ""
  property string section: ""
  property int sectionWidgetIndex: -1
  property int sectionWidgetsCount: 0

  property var widgetMetadata: BarWidgetRegistry.widgetMetadata[widgetId] || {}
  property var defaultSettings: widgetMetadata.defaultSettings || {}
  readonly property string screenName: screen ? screen.name : ""
  property var widgetSettings: {
    if (section && sectionWidgetIndex >= 0 && screenName) {
      var widgets = Settings.getBarWidgetsForScreen(screenName)[section];
      if (widgets && sectionWidgetIndex < widgets.length) {
        return widgets[sectionWidgetIndex];
      }
    }
    return {};
  }

  readonly property bool followFocusedScreen: widgetSettings.followFocusedScreen !== undefined
    ? widgetSettings.followFocusedScreen
    : (defaultSettings.followFocusedScreen !== undefined ? defaultSettings.followFocusedScreen : false)
  readonly property bool hideUnoccupied: widgetSettings.hideUnoccupied !== undefined
    ? widgetSettings.hideUnoccupied
    : (defaultSettings.hideUnoccupied !== undefined ? defaultSettings.hideUnoccupied : false)
  readonly property real barHeight: Style.getBarHeightForScreen(screenName)
  readonly property real capsuleHeight: Style.getCapsuleHeightForScreen(screenName)
  readonly property real barFontSize: Style.getBarFontSizeForScreen(screenName)
  readonly property real cellSize: Style.toOdd(capsuleHeight * 0.72)

  property var profiles: []
  property string loadError: "loading"
  property var cells: []
  property bool isDestroying: false

  implicitWidth: strip.implicitWidth
  implicitHeight: barHeight

  function focusedOutput() {
    for (var i = 0; i < CompositorService.workspaces.count; i++) {
      var ws = CompositorService.workspaces.get(i);
      if (ws && ws.isFocused) {
        return ws.output || "";
      }
    }
    return "";
  }

  function workspaceSnapshot() {
    var result = [];
    for (var i = 0; i < CompositorService.workspaces.count; i++) {
      var ws = CompositorService.workspaces.get(i);
      result.push({
        id: ws.id,
        idx: ws.idx,
        name: ws.name,
        output: ws.output,
        isFocused: ws.isFocused,
        isActive: ws.isActive,
        isUrgent: ws.isUrgent,
        isOccupied: ws.isOccupied
      });
    }
    return result;
  }

  function refreshCells() {
    var filtered = Logic.filterWorkspaces(root.workspaceSnapshot(), {
      screenName: root.screenName,
      focusedOutput: root.focusedOutput(),
      globalWorkspaces: CompositorService.globalWorkspaces,
      followFocusedScreen: root.followFocusedScreen,
      hideUnoccupied: root.hideUnoccupied
    });
    root.cells = Logic.buildCells(filtered, root.profiles);
  }

  function scheduleRefresh() {
    if (!root.isDestroying) {
      Qt.callLater(root.refreshCells);
    }
  }

  function applyProfileText(text) {
    var result = Logic.parseProfiles(text);
    root.profiles = result.profiles;
    root.loadError = result.error || "";
    if (result.error) {
      Logger.w("WorkspaceProfilesBar", "wsprofiles.json parse failed:", result.error);
    }
    root.scheduleRefresh();
  }

  function clearProfiles(errorText) {
    root.profiles = [];
    root.loadError = errorText;
    if (errorText) {
      Logger.w("WorkspaceProfilesBar", "wsprofiles.json load failed:", errorText);
    }
    root.scheduleRefresh();
  }

  function liveWorkspaceForCell(cell) {
    for (var i = 0; i < CompositorService.workspaces.count; i++) {
      var ws = CompositorService.workspaces.get(i);
      if (ws && ws.id === cell.id) {
        return ws;
      }
    }
    return null;
  }

  function switchCell(cell) {
    if (!cell || cell.idx === undefined || cell.idx === null) {
      return;
    }

    var live = root.liveWorkspaceForCell(cell);
    if (!live || live.isFocused) {
      return;
    }

    CompositorService.switchToWorkspace(live);
  }

  function cellBackground(cell, hovered) {
    if (cell.isFocused && cell.hasProfile && cell.ring) {
      return cell.ring;
    }
    if (hovered) {
      return Color.mHover;
    }
    if (cell.isFocused) {
      return Color.mSurfaceVariant;
    }
    return "transparent";
  }

  function cellForeground(cell, hovered) {
    if (cell.isFocused && cell.hasProfile && cell.ring) {
      return Logic.pickForeground(cell.ring);
    }
    if (hovered) {
      return Color.mOnHover;
    }
    if (cell.hasProfile && cell.ring) {
      return cell.ring;
    }
    return Color.mOnSurface;
  }

  function cellBorder(cell) {
    if (cell.isUrgent) {
      return Color.mError;
    }
    if (cell.isFocused) {
      return Color.mOutline;
    }
    return "transparent";
  }

  Component.onCompleted: scheduleRefresh()
  Component.onDestruction: {
    root.isDestroying = true;
  }
  onScreenNameChanged: scheduleRefresh()
  onFollowFocusedScreenChanged: scheduleRefresh()
  onHideUnoccupiedChanged: scheduleRefresh()

  Connections {
    target: CompositorService
    function onWorkspacesChanged() {
      root.scheduleRefresh();
    }
    function onWindowListChanged() {
      root.scheduleRefresh();
    }
    function onActiveWindowChanged() {
      root.scheduleRefresh();
    }
  }

  FileView {
    id: catalogView
    path: Quickshell.env("HOME") + "/.config/niri/wsprofiles.json"
    blockLoading: true
    watchChanges: true
    onFileChanged: {
      this.reload();
    }
    onLoaded: root.applyProfileText(catalogView.text())
    onLoadFailed: root.clearProfiles("load failed: " + catalogView.path)
  }

  Row {
    id: strip
    anchors.centerIn: parent
    spacing: Style.marginXS

    Repeater {
      model: root.cells

      delegate: Item {
        id: cellItem

        property var cell: modelData
        readonly property bool expanded: cell.isFocused
        readonly property real maxExpandedWidth: Math.max(root.cellSize * 3, root.capsuleHeight * 7)
        readonly property real maxLabelWidth: Math.max(0, maxExpandedWidth - root.cellSize - Style.marginXS - Style.marginM * 2)
        readonly property real expandedWidth: Math.min(maxExpandedWidth, Math.max(root.cellSize * 2.4, content.implicitWidth + Style.marginM * 2))

        width: expanded ? expandedWidth : root.cellSize
        height: root.barHeight

        Behavior on width {
          NumberAnimation {
            duration: Style.animationNormal
            easing.type: Easing.OutBack
          }
        }

        Rectangle {
          id: pill
          anchors.centerIn: parent
          width: parent.width
          height: root.cellSize
          radius: height / 2
          color: root.cellBackground(cellItem.cell, mouseArea.containsMouse)
          border.color: root.cellBorder(cellItem.cell)
          border.width: cellItem.cell.isUrgent || cellItem.cell.isFocused ? 1 : 0
          opacity: cellItem.cell.isFocused || cellItem.cell.isOccupied ? Style.opacityFull : Style.opacityMedium

          Behavior on color {
            enabled: !Color.isTransitioning
            ColorAnimation {
              duration: Style.animationFast
              easing.type: Easing.InOutQuad
            }
          }

          Behavior on opacity {
            NumberAnimation {
              duration: Style.animationFast
              easing.type: Easing.InOutCubic
            }
          }
        }

        Row {
          id: content
          anchors.centerIn: pill
          spacing: Style.marginXS

          NText {
            id: glyphText
            text: cellItem.cell.glyph
            pointSize: root.barFontSize
            applyUiScale: false
            font.weight: Style.fontWeightBold
            color: root.cellForeground(cellItem.cell, mouseArea.containsMouse)
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
          }

          NText {
            id: labelText
            visible: cellItem.expanded
            width: cellItem.expanded ? Math.min(implicitWidth, cellItem.maxLabelWidth) : 0
            text: cellItem.cell.label
            pointSize: root.barFontSize
            applyUiScale: false
            font.weight: Style.fontWeightMedium
            color: root.cellForeground(cellItem.cell, mouseArea.containsMouse)
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            maximumLineCount: 1
            elide: Text.ElideRight
          }
        }

        MouseArea {
          id: mouseArea
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          hoverEnabled: true

          onEntered: {
            TooltipService.show(cellItem, cellItem.cell.label, BarService.getTooltipDirection(root.screenName));
          }
          onExited: {
            TooltipService.hide();
          }
          onClicked: {
            TooltipService.hide();
            root.switchCell(cellItem.cell);
          }
        }
      }
    }
  }
}
```

- [ ] **Step 2: Run the pure logic tests after adding QML**

Run:

```bash
rtk node --test ~/d/dotfiles/noctalia/plugins/niri-workspace-profiles/logic.test.mjs
```

Expected: PASS.

- [ ] **Step 3: Commit**

Run:

```bash
rtk git add noctalia/plugins/niri-workspace-profiles/BarWidget.qml
rtk git commit -m "feat(noctalia): render workspace profile bar widget"
```

Expected: commit succeeds.

### Task 4: Local Plugin Link and Manual Verification

**Files:**
- Local artifact: `~/.config/noctalia/plugins/niri-workspace-profiles`
- Read: `~/.config/niri/wsprofiles.json`
- Read/restore during manual check: `~/.config/niri/wsprofiles.json`

- [ ] **Step 1: Create the local noctalia plugin symlink**

Run:

```bash
rtk mkdir -p ~/.config/noctalia/plugins
rtk ln -sfn ~/d/dotfiles/noctalia/plugins/niri-workspace-profiles ~/.config/noctalia/plugins/niri-workspace-profiles
rtk ls -l ~/.config/noctalia/plugins/niri-workspace-profiles
```

Expected: the symlink points to `~/d/dotfiles/noctalia/plugins/niri-workspace-profiles`.

- [ ] **Step 2: Run automated verification**

Run:

```bash
rtk node --test ~/d/dotfiles/noctalia/plugins/niri-workspace-profiles/logic.test.mjs
(cd ~/d/dotfiles/wsprofiles && rtk npm test)
```

Expected: both commands pass. `npm test` should still report the existing wsprofiles suite passing.

- [ ] **Step 3: Enable the bar widget manually**

In noctalia settings, enable the `Niri Workspace Profiles` plugin, add `plugin:niri-workspace-profiles` to the same horizontal bar section where `Workspace` currently lives, and remove the core `Workspace` widget from that horizontal bar section. Do not replace the core `Workspace` widget on left/right vertical bars in v1.

Expected: the horizontal bar renders one workspace-profile cell per workspace visible on that bar's screen. Vertical bars, if configured, still use noctalia's core `Workspace` widget.

- [ ] **Step 4: Verify profile glyph and color rendering**

Check the live bar:

```text
ember shows glyph E in #ff7a45 when its catalog icon is empty.
tide and tide-2 show glyph T in #3aa6ff when their catalog icon is empty.
If a real icon is added to wsprofiles/profiles.yaml and wsprofiled accepts it, that icon replaces the first-letter fallback.
```

Expected: profiled unfocused workspaces show colored glyphs; unprofiled workspaces show neutral `idx` glyphs.

- [ ] **Step 5: Verify focus and click behavior**

Perform:

```text
Focus tide using Mod+P.
Click ember's bar cell.
Click tide-2's bar cell.
```

Expected: the focused workspace becomes a filled pill in its ring color with glyph plus label; clicking a cell focuses that workspace and the daemon applies the matching shell theme.

- [ ] **Step 6: Verify focused hover preserves profile identity**

Perform:

```text
Focus a profiled workspace such as ember or tide.
Move the pointer over that focused cell.
Move the pointer over an unfocused cell.
```

Expected: the focused profiled cell keeps its ring-colored filled pill while hovered; unfocused cells may use noctalia hover styling.

- [ ] **Step 7: Verify missing and malformed JSON fallback**

Run these commands only after confirming `~/.config/niri/wsprofiles.json` exists:

```bash
rtk cp ~/.config/niri/wsprofiles.json /tmp/wsprofiles.json.good
rtk mv ~/.config/niri/wsprofiles.json ~/.config/niri/wsprofiles.json.bak
```

Observe the bar.

Expected: the strip degrades to neutral numbered cells and noctalia does not crash.

Restore and corrupt the file:

```bash
rtk mv ~/.config/niri/wsprofiles.json.bak ~/.config/niri/wsprofiles.json
rtk sh -c "printf '{ not json\n' > ~/.config/niri/wsprofiles.json"
```

Observe the bar.

Expected: the strip stays neutral, `WorkspaceProfilesBar` logs a load or parse warning in the noctalia/`qs` log, and noctalia does not crash.

Restore the valid file:

```bash
rtk cp /tmp/wsprofiles.json.good ~/.config/niri/wsprofiles.json
```

Expected: profile colors return without a noctalia restart.

- [ ] **Step 8: Verify per-screen filtering**

On a multi-output niri session, place workspaces on at least two outputs.

Expected with default settings on horizontal bars: each plugin instance shows only workspaces whose `ws.output` matches that bar's screen, even if the output names differ by case in Quickshell/niri data. If `hideUnoccupied` is enabled for this plugin instance in noctalia settings JSON, empty non-focused workspaces disappear and the focused workspace remains visible.

- [ ] **Step 9: Final verification and diff check**

Run:

```bash
rtk node --test ~/d/dotfiles/noctalia/plugins/niri-workspace-profiles/logic.test.mjs
(cd ~/d/dotfiles/wsprofiles && rtk npm test)
rtk git diff --check
```

Expected: all commands pass with no whitespace errors.

## Self-Review

**Spec coverage:** Task 1 covers `parseProfiles`, `resolveProfile`, `filterWorkspaces`, `buildCells`, empty-icon fallback, unprofiled glyphs, mixed-case output normalization, and `pickForeground`. Task 2 covers the noctalia plugin package and manifest registration. Task 3 covers FileView watching, corrupt/missing JSON fallback with logging, the QML reactivity bridge, horizontal cell rendering, focused-hover behavior, tooltip behavior, and click-to-focus. Task 4 covers symlink setup and the manual noctalia/niri verification steps, including the v1 constraint that vertical bars keep the core `Workspace` widget.

**Placeholder scan:** This plan contains exact file paths, commands, expected outcomes, and complete code for every created source file.

**Type consistency:** The QML imports `logic.js` as `Logic` and calls the same functions defined and tested in Task 1: `parseProfiles`, `filterWorkspaces`, `buildCells`, and `pickForeground`. `cell` objects use the Task 1 contract: `id`, `idx`, `name`, `output`, `hasProfile`, `ring`, `glyph`, `label`, `isFocused`, `isOccupied`, and `isUrgent`.
