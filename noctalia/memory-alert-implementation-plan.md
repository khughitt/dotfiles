# Persistent Memory Pressure Alert Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox syntax for tracking.

**Goal:** Add a persistent, two-stage Noctalia memory-pressure banner that is shown on every screen and shares thresholds with the existing System Monitor.

**Architecture:** A headless plugin registers with Noctalia's existing SystemStatService and feeds its five-second samples into a pure JavaScript reducer. One controller owns alert and configuration state; Variants creates a presentation-only layer-shell window for each screen. Plugin installation uses the existing dotfiles setup and health conventions.

**Tech Stack:** QML/QtQuick, Quickshell and WlrLayershell, Noctalia 4.7.7 APIs, JavaScript with Node's built-in test runner, Zsh setup tests.

**Verified Preflight:** The layer-shell spike already passed when `Main.qml` was dynamically created with Noctalia's actual parent condition: `createObject(pluginContainer)` where `pluginContainer` is a visual `Item` in the graphics scene. Implementation should preserve that `Main.qml` → `Variants` → `PanelWindow` ownership shape; no additional screen-resolution spike is required.

## Global Constraints

- Require Noctalia 4.7.7 or newer.
- Register exactly one SystemStatService consumer and do not add another timer or read /proc/meminfo directly.
- Inherit SystemStatService.memWarningThreshold and memCriticalThreshold; do not duplicate them in plugin settings.
- Leave current and shipped 80/90 warning/critical settings unchanged during installation. Document 70/85 as an optional profile that also retunes the bar gauge.
- Default warning recovery to 65. Derive critical recovery as max(warning, critical - 5).
- Render the same logical alert on every Quickshell screen.
- A dismissed warning must reappear on critical escalation. A dismissed critical alert remains hidden until warning recovery.
- Invalid ordering must disarm memory transitions and show a persistent, non-dismissible configuration-error banner on every screen.
- Polling pauses on Noctalia's lock screen; a crossing while locked appears on the first refreshed sample after unlock.
- Launch the monitor with the argument array ["ghostty", "-e", "btop"]; do not parse or execute a shell command string.
- Add no sound, automatic process killing, compatibility layer, or component name beginning with Unified.
- Use relative repository paths in commands and ~/d paths in documentation.
- Preserve unrelated working-tree changes, including niri/familiar.kdl and ghostty/.

## File Map

- Create noctalia/plugins/memory-pressure-alert/manifest.json — plugin metadata and defaults.
- Create noctalia/plugins/memory-pressure-alert/logic.js — validation and pure memory-state reducer.
- Create noctalia/plugins/memory-pressure-alert/logic.test.mjs — reducer and validation tests.
- Create noctalia/plugins/memory-pressure-alert/Main.qml — plugin lifecycle, service integration, shared state, actions, and per-screen view creation.
- Create noctalia/plugins/memory-pressure-alert/AlertWindow.qml — layer-shell banner presentation.
- Create noctalia/plugins/memory-pressure-alert/Settings.qml — warning-recovery editor and inherited-threshold explanation.
- Create noctalia/plugins/memory-pressure-alert/qml_contract.test.mjs — static architectural contract for the QML boundary.
- Create noctalia/plugins/memory-pressure-alert/README.md — plugin usage and threshold behavior.
- Modify setup.sh — install the second managed local Noctalia plugin link.
- Modify bin/dotfiles-health — validate the memory-pressure-alert link when Noctalia configuration is present.
- Modify tests/setup_and_health.zsh — cover graphical plugin installation and broken-link detection.
- Modify noctalia/noctalia.md — document enabling, configuration, and verification.

---

### Task 1: Pure alert state and configuration validation

**Files:**
- Create: noctalia/plugins/memory-pressure-alert/manifest.json
- Create: noctalia/plugins/memory-pressure-alert/logic.js
- Create: noctalia/plugins/memory-pressure-alert/logic.test.mjs

**Interfaces:**
- Produces: validateConfig(config), returning either `{ valid: false, message, settingsTarget }` or `{ valid: true, message, settingsTarget, recoveryThreshold, warningThreshold, criticalRecoveryThreshold, criticalThreshold }`.
- Produces: initialState() returning the complete reducer state.
- Produces: reduceMemoryState(state, event, thresholds) accepting sample and dismiss events.
- Consumers: Main.qml and Settings.qml in Task 2.

- [ ] **Step 1: Write the failing Node tests**

Create logic.test.mjs with:

~~~javascript
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import vm from "node:vm";

function loadLogic() {
  const path = fileURLToPath(new URL("./logic.js", import.meta.url));
  const source = readFileSync(path, "utf8").replace(/^\s*\.pragma\s+library\s*$/m, "");
  const context = {};
  vm.runInNewContext(source, context);
  return context;
}

function plain(value) {
  return JSON.parse(JSON.stringify(value));
}

const Logic = loadLogic();
const thresholds = {
  recoveryThreshold: 65,
  warningThreshold: 70,
  criticalThreshold: 85,
};

test("validateConfig derives critical recovery for current and early profiles", () => {
  assert.deepEqual(plain(Logic.validateConfig({
    recoveryThreshold: 65,
    warningThreshold: 80,
    criticalThreshold: 90,
  })), {
    valid: true,
    message: "",
    settingsTarget: "",
    recoveryThreshold: 65,
    warningThreshold: 80,
    criticalRecoveryThreshold: 85,
    criticalThreshold: 90,
  });

  assert.equal(Logic.validateConfig(thresholds).criticalRecoveryThreshold, 80);
  assert.equal(Logic.validateConfig({
    recoveryThreshold: 65,
    warningThreshold: 80,
    criticalThreshold: 82,
  }).criticalRecoveryThreshold, 80);
});

test("validateConfig identifies which settings surface must be fixed", () => {
  const recoveryError = Logic.validateConfig({
    recoveryThreshold: 80,
    warningThreshold: 80,
    criticalThreshold: 90,
  });
  assert.equal(recoveryError.valid, false);
  assert.equal(recoveryError.settingsTarget, "plugin");
  assert.match(recoveryError.message, /Recovery threshold/);

  const systemError = Logic.validateConfig({
    recoveryThreshold: 65,
    warningThreshold: 90,
    criticalThreshold: 90,
  });
  assert.equal(systemError.valid, false);
  assert.equal(systemError.settingsTarget, "system");
  assert.match(systemError.message, /Warning threshold/);

  const mixedError = Logic.validateConfig({
    recoveryThreshold: 90,
    warningThreshold: 90,
    criticalThreshold: 90,
  });
  assert.equal(mixedError.settingsTarget, "system");
  assert.match(mixedError.message, /Warning threshold/);
});

test("startup samples enter warning or critical at inclusive boundaries", () => {
  const valid = Logic.validateConfig(thresholds);
  const warning = Logic.reduceMemoryState(
    Logic.initialState(),
    { type: "sample", percent: 70 },
    valid,
  );
  assert.equal(warning.level, "warning");
  assert.equal(warning.visible, true);

  const critical = Logic.reduceMemoryState(
    Logic.initialState(),
    { type: "sample", percent: 85 },
    valid,
  );
  assert.equal(critical.level, "critical");
  assert.equal(critical.visible, true);
  assert.equal(critical.criticalGeneration, 1);
});

test("warning dismissal is overridden by critical escalation", () => {
  const valid = Logic.validateConfig(thresholds);
  let state = Logic.reduceMemoryState(
    Logic.initialState(),
    { type: "sample", percent: 70 },
    valid,
  );
  state = Logic.reduceMemoryState(state, { type: "dismiss" }, valid);
  assert.equal(state.visible, false);
  assert.equal(state.warningAcknowledged, true);

  state = Logic.reduceMemoryState(state, { type: "sample", percent: 85 }, valid);
  assert.equal(state.level, "critical");
  assert.equal(state.visible, true);
  assert.equal(state.warningAcknowledged, false);
});

test("critical remains latched until below the derived recovery threshold", () => {
  const valid = Logic.validateConfig(thresholds);
  let state = Logic.reduceMemoryState(
    Logic.initialState(),
    { type: "sample", percent: 85 },
    valid,
  );
  state = Logic.reduceMemoryState(state, { type: "sample", percent: 84 }, valid);
  assert.equal(state.level, "critical");
  assert.equal(state.criticalGeneration, 1);

  state = Logic.reduceMemoryState(state, { type: "sample", percent: 80 }, valid);
  assert.equal(state.level, "critical");

  state = Logic.reduceMemoryState(state, { type: "sample", percent: 79 }, valid);
  assert.equal(state.level, "warning");
  assert.equal(state.visible, true);
});

test("critical dismissal suppresses the rest of the episode", () => {
  const valid = Logic.validateConfig(thresholds);
  let state = Logic.reduceMemoryState(
    Logic.initialState(),
    { type: "sample", percent: 85 },
    valid,
  );
  state = Logic.reduceMemoryState(state, { type: "dismiss" }, valid);
  state = Logic.reduceMemoryState(state, { type: "sample", percent: 70 }, valid);
  state = Logic.reduceMemoryState(state, { type: "sample", percent: 90 }, valid);
  assert.equal(state.visible, false);
  assert.equal(state.criticalAcknowledged, true);
});

test("warning recovery clears acknowledgements and arms a new episode", () => {
  const valid = Logic.validateConfig(thresholds);
  let state = Logic.reduceMemoryState(
    Logic.initialState(),
    { type: "sample", percent: 70 },
    valid,
  );
  state = Logic.reduceMemoryState(state, { type: "dismiss" }, valid);
  state = Logic.reduceMemoryState(state, { type: "sample", percent: 65 }, valid);
  assert.equal(state.episodeActive, true);

  state = Logic.reduceMemoryState(state, { type: "sample", percent: 64 }, valid);
  assert.deepEqual(plain(state), plain(Logic.initialState()));

  state = Logic.reduceMemoryState(state, { type: "sample", percent: 70 }, valid);
  assert.equal(state.visible, true);
});

test("malformed events and invalid thresholds fail early", () => {
  const valid = Logic.validateConfig(thresholds);
  assert.throws(
    () => Logic.reduceMemoryState(Logic.initialState(), { type: "sample", percent: NaN }, valid),
    /finite percentage/,
  );
  assert.throws(
    () => Logic.reduceMemoryState(Logic.initialState(), { type: "unknown" }, valid),
    /Unknown memory alert event/,
  );
  assert.throws(
    () => Logic.reduceMemoryState(
      Logic.initialState(),
      { type: "sample", percent: 70 },
      Logic.validateConfig({ recoveryThreshold: 70, warningThreshold: 70, criticalThreshold: 85 }),
    ),
    /valid thresholds/,
  );
});
~~~

- [ ] **Step 2: Run the tests and verify the expected failure**

Run:

~~~bash
node --test noctalia/plugins/memory-pressure-alert/logic.test.mjs
~~~

Expected: FAIL with ENOENT for logic.js.

- [ ] **Step 3: Implement the pure logic**

Create logic.js with:

~~~javascript
.pragma library

function isWholePercentage(value) {
  return typeof value === "number"
    && isFinite(value)
    && Math.floor(value) === value
    && value >= 0
    && value <= 100;
}

function invalidConfig(message, settingsTarget) {
  return {
    valid: false,
    message: message,
    settingsTarget: settingsTarget,
  };
}

function validateConfig(config) {
  if (!config || !isWholePercentage(config.recoveryThreshold)) {
    return invalidConfig("Recovery threshold must be a whole percentage from 0 to 100.", "plugin");
  }
  if (!isWholePercentage(config.warningThreshold)
      || !isWholePercentage(config.criticalThreshold)) {
    return invalidConfig("System Monitor memory thresholds must be whole percentages from 0 to 100.", "system");
  }
  if (config.warningThreshold >= config.criticalThreshold) {
    return invalidConfig(
      "Warning threshold (" + config.warningThreshold
        + "%) must be lower than critical threshold ("
        + config.criticalThreshold + "%).",
      "system",
    );
  }
  if (config.recoveryThreshold >= config.warningThreshold) {
    return invalidConfig(
      "Recovery threshold (" + config.recoveryThreshold
        + "%) must be lower than warning threshold ("
        + config.warningThreshold + "%).",
      "plugin",
    );
  }

  return {
    valid: true,
    message: "",
    settingsTarget: "",
    recoveryThreshold: config.recoveryThreshold,
    warningThreshold: config.warningThreshold,
    criticalRecoveryThreshold: Math.max(
      config.warningThreshold,
      config.criticalThreshold - 5,
    ),
    criticalThreshold: config.criticalThreshold,
  };
}

function initialState() {
  return {
    episodeActive: false,
    level: "normal",
    warningAcknowledged: false,
    criticalAcknowledged: false,
    criticalLatched: false,
    criticalGeneration: 0,
    visible: false,
  };
}

function copyState(state) {
  return {
    episodeActive: !!state.episodeActive,
    level: state.level || "normal",
    warningAcknowledged: !!state.warningAcknowledged,
    criticalAcknowledged: !!state.criticalAcknowledged,
    criticalLatched: !!state.criticalLatched,
    criticalGeneration: state.criticalGeneration || 0,
    visible: !!state.visible,
  };
}

function reduceMemoryState(state, event, thresholds) {
  if (!thresholds || thresholds.valid !== true) {
    throw new Error("Memory alert reducer requires valid thresholds.");
  }

  var next = copyState(state || initialState());

  if (event && event.type === "dismiss") {
    if (!next.visible) {
      return next;
    }
    if (next.level === "critical") {
      next.criticalAcknowledged = true;
    } else if (next.level === "warning") {
      next.warningAcknowledged = true;
    }
    next.visible = false;
    return next;
  }

  if (!event || event.type !== "sample") {
    throw new Error("Unknown memory alert event.");
  }
  if (typeof event.percent !== "number" || !isFinite(event.percent)) {
    throw new Error("Memory sample must be a finite percentage.");
  }

  var percent = event.percent;
  if (percent < thresholds.recoveryThreshold) {
    return initialState();
  }

  if (!next.episodeActive) {
    if (percent < thresholds.warningThreshold) {
      return initialState();
    }
    next.episodeActive = true;
    next.level = "warning";
  }

  if (next.criticalAcknowledged) {
    next.visible = false;
    return next;
  }

  if (!next.criticalLatched && percent >= thresholds.criticalThreshold) {
    next.criticalLatched = true;
    next.warningAcknowledged = false;
    next.criticalGeneration += 1;
  } else if (next.criticalLatched
             && percent < thresholds.criticalRecoveryThreshold) {
    next.criticalLatched = false;
  }

  next.level = next.criticalLatched ? "critical" : "warning";
  next.visible = next.level === "critical" || !next.warningAcknowledged;
  return next;
}
~~~

- [ ] **Step 4: Add the plugin manifest**

Create manifest.json with:

~~~json
{
  "id": "memory-pressure-alert",
  "name": "Memory Pressure Alert",
  "version": "1.0.0",
  "minNoctaliaVersion": "4.7.7",
  "author": "Keith Hughitt",
  "license": "MIT",
  "description": "Persistent warning and critical memory-pressure banners.",
  "tags": ["System", "Alert"],
  "entryPoints": {
    "main": "Main.qml",
    "settings": "Settings.qml"
  },
  "dependencies": {
    "plugins": []
  },
  "metadata": {
    "defaultSettings": {
      "recoveryThreshold": 65,
      "monitorCommand": ["ghostty", "-e", "btop"]
    }
  }
}
~~~

- [ ] **Step 5: Run logic and manifest validation**

Run:

~~~bash
node --test noctalia/plugins/memory-pressure-alert/logic.test.mjs
jq empty noctalia/plugins/memory-pressure-alert/manifest.json
~~~

Expected: 8 tests pass and jq exits 0.

- [ ] **Step 6: Commit the pure model**

~~~bash
git add noctalia/plugins/memory-pressure-alert/manifest.json noctalia/plugins/memory-pressure-alert/logic.js noctalia/plugins/memory-pressure-alert/logic.test.mjs
git commit -m "feat(noctalia): add memory alert state model"
~~~

---

### Task 2: Noctalia controller, per-screen banner, and settings

**Files:**
- Create: noctalia/plugins/memory-pressure-alert/qml_contract.test.mjs
- Create: noctalia/plugins/memory-pressure-alert/Main.qml
- Create: noctalia/plugins/memory-pressure-alert/AlertWindow.qml
- Create: noctalia/plugins/memory-pressure-alert/Settings.qml

**Interfaces:**
- Consumes: Logic.validateConfig, Logic.initialState, and Logic.reduceMemoryState from Task 1.
- Consumes: SystemStatService.memPercent, memGb, memTotalGb, memWarningThreshold, memCriticalThreshold, warningColor, and criticalColor.
- Produces: one AlertWindow per Quickshell.screens entry, driven by one shared memoryState.
- Produces: Settings.qml saveSettings() for Noctalia's plugin settings host.

- [ ] **Step 1: Write a failing QML architecture contract**

Create qml_contract.test.mjs with:

~~~javascript
import { test } from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";

function source(name) {
  return readFileSync(fileURLToPath(new URL(name, import.meta.url)), "utf8");
}

test("Main owns one SystemStatService registration and no timer", () => {
  const main = source("./Main.qml");
  assert.match(main, /registerComponent\("plugin:memory-pressure-alert"\)/);
  assert.match(main, /unregisterComponent\("plugin:memory-pressure-alert"\)/);
  assert.doesNotMatch(main, /\bTimer\s*\{/);
});

test("Main replicates one shared state across all screens", () => {
  const main = source("./Main.qml");
  assert.match(main, /Variants\s*\{[\s\S]*model:\s*Quickshell\.screens/);
  assert.match(main, /property var memoryState:/);
  assert.match(
    main,
    /alertVisible:\s*root\.configurationInvalid\s*\|\|\s*root\.memoryState\.visible/,
  );
  assert.match(main, /configuration-error/);
});

test("AlertWindow is a nonexclusive overlay and error state cannot dismiss", () => {
  const view = source("./AlertWindow.qml");
  assert.match(view, /^PanelWindow\s*\{/m);
  assert.match(view, /WlrLayershell\.layer:\s*WlrLayer\.Overlay/);
  assert.match(view, /WlrLayershell\.exclusionMode:\s*ExclusionMode\.Ignore/);
  assert.match(view, /WlrLayershell\.keyboardFocus:\s*WlrKeyboardFocus\.None/);
  assert.match(view, /visible:\s*root\.presentationMode !== "configuration-error"/);
});

test("Settings edits recovery only and displays shared thresholds", () => {
  const settings = source("./Settings.qml");
  assert.match(settings, /recoveryThreshold/);
  assert.match(settings, /SystemStatService\.memWarningThreshold/);
  assert.match(settings, /SystemStatService\.memCriticalThreshold/);
  assert.doesNotMatch(settings, /pluginSettings\.warningThreshold/);
  assert.doesNotMatch(settings, /pluginSettings\.criticalThreshold/);
});
~~~

- [ ] **Step 2: Run the contract and verify the expected failure**

Run:

~~~bash
node --test noctalia/plugins/memory-pressure-alert/qml_contract.test.mjs
~~~

Expected: FAIL with ENOENT for Main.qml.

- [ ] **Step 3: Implement the shared controller**

Create Main.qml with:

~~~qml
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.System
import qs.Services.UI
import "logic.js" as Logic

Item {
  id: root

  property var pluginApi: null
  property bool started: false
  property var memoryState: Logic.initialState()

  readonly property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})
  readonly property int recoveryThreshold:
    pluginApi?.pluginSettings?.recoveryThreshold ?? defaults.recoveryThreshold ?? 65
  readonly property var monitorCommand:
    pluginApi?.pluginSettings?.monitorCommand ?? defaults.monitorCommand ?? ["ghostty", "-e", "btop"]
  readonly property int warningThreshold: SystemStatService.memWarningThreshold
  readonly property int criticalThreshold: SystemStatService.memCriticalThreshold
  readonly property var configValidation: Logic.validateConfig({
    recoveryThreshold: root.recoveryThreshold,
    warningThreshold: root.warningThreshold,
    criticalThreshold: root.criticalThreshold
  })

  readonly property bool configurationInvalid: !root.configValidation.valid
  readonly property bool alertVisible:
    root.configurationInvalid || root.memoryState.visible
  readonly property string presentationMode:
    root.configurationInvalid ? "configuration-error" : root.memoryState.level
  readonly property real availableGb:
    Math.max(0, SystemStatService.memTotalGb - SystemStatService.memGb)

  function refreshFromCurrentSample() {
    root.memoryState = Logic.initialState();
    if (!root.started)
      return;
    if (root.configurationInvalid) {
      Logger.e("MemoryPressureAlert", root.configValidation.message);
      return;
    }
    handleSample(SystemStatService.memPercent);
  }

  function handleSample(percent) {
    if (!root.started || root.configurationInvalid)
      return;
    try {
      root.memoryState = Logic.reduceMemoryState(
        root.memoryState,
        { type: "sample", percent: percent },
        root.configValidation
      );
    } catch (error) {
      Logger.e("MemoryPressureAlert", "Ignoring malformed memory sample:", error);
    }
  }

  function dismissAlert() {
    if (root.configurationInvalid)
      return;
    root.memoryState = Logic.reduceMemoryState(
      root.memoryState,
      { type: "dismiss" },
      root.configValidation
    );
  }

  function validCommand(command) {
    return Array.isArray(command)
      && command.length > 0
      && command.every(part => typeof part === "string" && part.length > 0);
  }

  function openMonitor() {
    if (!validCommand(root.monitorCommand)) {
      ToastService.showError(
        "Memory pressure alert",
        "monitorCommand must be a non-empty argument array."
      );
      return;
    }
    if (!monitorProcess.running)
      monitorProcess.running = true;
  }

  function openConfigurationSettings() {
    const command = root.configValidation.settingsTarget === "plugin"
      ? ["qs", "-c", "noctalia-shell", "ipc", "call",
         "plugin", "openSettings", "memory-pressure-alert"]
      : ["qs", "-c", "noctalia-shell", "ipc", "call",
         "settings", "openTab", "system/1"];
    Quickshell.execDetached(command);
  }

  Process {
    id: monitorProcess
    running: false
    command: root.monitorCommand

    onExited: function(exitCode) {
      if (exitCode !== 0) {
        ToastService.showError(
          "Memory pressure alert",
          "Failed to launch: " + root.monitorCommand.join(" ")
        );
      }
    }
  }

  Connections {
    target: SystemStatService

    function onMemPercentChanged() {
      root.handleSample(SystemStatService.memPercent);
    }
  }

  onConfigValidationChanged: {
    if (root.started)
      root.refreshFromCurrentSample();
  }

  Component.onCompleted: {
    SystemStatService.registerComponent("plugin:memory-pressure-alert");
    root.started = true;
    root.refreshFromCurrentSample();
  }

  Component.onDestruction: {
    SystemStatService.unregisterComponent("plugin:memory-pressure-alert");
  }

  Variants {
    model: Quickshell.screens

    delegate: AlertWindow {
      required property ShellScreen modelData

      screen: modelData
      shown: root.alertVisible
      presentationMode: root.presentationMode
      configurationError: root.configValidation.message || ""
      memoryPercent: SystemStatService.memPercent
      usedGb: SystemStatService.memGb
      totalGb: SystemStatService.memTotalGb
      availableGb: root.availableGb
      warningColor: SystemStatService.warningColor
      criticalColor: SystemStatService.criticalColor
      criticalGeneration: root.memoryState.criticalGeneration

      onDismissRequested: root.dismissAlert()
      onOpenMonitorRequested: root.openMonitor()
      onOpenSettingsRequested: root.openConfigurationSettings()
    }
  }
}
~~~

- [ ] **Step 4: Implement the per-screen persistent view**

Create AlertWindow.qml with:

~~~qml
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.Commons
import qs.Widgets

PanelWindow {
  id: root

  property bool shown: false
  property string presentationMode: "normal"
  property string configurationError: ""
  property real memoryPercent: 0
  property real usedGb: 0
  property real totalGb: 0
  property real availableGb: 0
  property color warningColor: Color.mTertiary
  property color criticalColor: Color.mError
  property int criticalGeneration: 0

  signal dismissRequested
  signal openMonitorRequested
  signal openSettingsRequested

  readonly property bool isConfigurationError:
    presentationMode === "configuration-error"
  readonly property bool isCritical: presentationMode === "critical"
  readonly property color accentColor:
    isCritical || isConfigurationError ? criticalColor : warningColor
  readonly property string titleText: {
    if (isConfigurationError)
      return "Memory alert disabled";
    return isCritical ? "Memory critically high" : "Memory high";
  }
  readonly property string detailText: {
    if (isConfigurationError)
      return configurationError;
    return Math.round(memoryPercent) + "% · "
      + Number(usedGb).toFixed(1) + " / "
      + Number(totalGb).toFixed(1) + " GiB used · "
      + Number(availableGb).toFixed(1) + " GiB available";
  }
  readonly property int shadowPadding: Style.shadowBlurMax + Style.marginL

  visible: shown
  implicitWidth: Math.min(
    Math.round(600 * Style.uiScaleRatio),
    Math.max(320, (screen?.width || 640) - Style.marginXL * 2)
  ) + shadowPadding * 2
  implicitHeight: banner.implicitHeight + shadowPadding * 2
  color: "transparent"

  anchors.top: true
  margins.top: {
    const screenName = screen?.name || "";
    const barAtTop = Settings.getBarPositionForScreen(screenName) === "top";
    return barAtTop
      ? Style.getBarHeightForScreen(screenName) + Style.marginM
      : Style.marginL;
  }

  WlrLayershell.namespace:
    "noctalia-memory-pressure-alert-" + (screen?.name || "unknown")
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.exclusionMode: ExclusionMode.Ignore
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

  Rectangle {
    id: banner
    anchors.fill: parent
    anchors.margins: root.shadowPadding
    implicitHeight: content.implicitHeight + Style.marginL * 2
    radius: Style.radiusL
    color: Color.mSurface
    border.color: root.accentColor
    border.width: Style.borderM
    transformOrigin: Item.Center

    RowLayout {
      id: content
      anchors.fill: parent
      anchors.margins: Style.marginL
      spacing: Style.marginM

      NIcon {
        icon: root.isConfigurationError ? "alert-triangle" : "memory"
        pointSize: Style.fontSizeXXL
        color: root.accentColor
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.marginXXS

        NText {
          Layout.fillWidth: true
          text: root.titleText
          pointSize: Style.fontSizeL
          font.weight: Style.fontWeightBold
          color: root.accentColor
        }

        NText {
          Layout.fillWidth: true
          text: root.detailText
          wrapMode: Text.Wrap
          color: Color.mOnSurface
        }
      }

      NButton {
        visible: !root.isConfigurationError
        text: "Open btop"
        outlined: true
        backgroundColor: root.accentColor
        onClicked: root.openMonitorRequested()
      }

      NButton {
        visible: root.isConfigurationError
        text: "Open settings"
        backgroundColor: root.accentColor
        onClicked: root.openSettingsRequested()
      }

      NButton {
        visible: root.presentationMode !== "configuration-error"
        text: "Dismiss"
        outlined: true
        backgroundColor: root.accentColor
        onClicked: root.dismissRequested()
      }
    }
  }

  NDropShadow {
    anchors.fill: banner
    source: banner
    autoPaddingEnabled: true
  }

  SequentialAnimation {
    id: criticalPulse

    NumberAnimation {
      target: banner
      property: "scale"
      from: 1
      to: 1.04
      duration: 160
      easing.type: Easing.OutCubic
    }
    NumberAnimation {
      target: banner
      property: "scale"
      to: 1
      duration: 220
      easing.type: Easing.InOutCubic
    }
  }

  onCriticalGenerationChanged: {
    if (root.shown && root.isCritical)
      criticalPulse.restart();
  }

  Component.onCompleted: {
    if (root.shown && root.isCritical)
      criticalPulse.restart();
  }
}
~~~

- [ ] **Step 5: Implement the plugin settings view**

Create Settings.qml with:

~~~qml
import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Services.System
import qs.Services.UI
import qs.Widgets
import "logic.js" as Logic

ColumnLayout {
  id: root

  property var pluginApi: null
  readonly property var defaults:
    pluginApi?.manifest?.metadata?.defaultSettings || ({})
  property int editRecoveryThreshold:
    pluginApi?.pluginSettings?.recoveryThreshold
      ?? defaults.recoveryThreshold
      ?? 65

  spacing: Style.marginM

  NLabel {
    label: "Shared memory thresholds"
    description: "Warning is currently "
      + SystemStatService.memWarningThreshold
      + "% and critical is "
      + SystemStatService.memCriticalThreshold
      + "%. Change them in Noctalia Settings → System Monitor → Thresholds. "
      + "Keeping 80/90 preserves defaults; 70/85 enables earlier alerts and "
      + "also retunes the bar gauge."
  }

  NSpinBox {
    Layout.fillWidth: true
    label: "Warning recovery"
    description: "A warning episode re-arms only after memory falls below this value."
    from: 0
    to: Math.max(0, SystemStatService.memWarningThreshold - 1)
    stepSize: 1
    suffix: "%"
    value: root.editRecoveryThreshold
    defaultValue: root.defaults.recoveryThreshold ?? 65
    onValueChanged: root.editRecoveryThreshold = value
  }

  function saveSettings() {
    const validation = Logic.validateConfig({
      recoveryThreshold: root.editRecoveryThreshold,
      warningThreshold: SystemStatService.memWarningThreshold,
      criticalThreshold: SystemStatService.memCriticalThreshold
    });
    if (!validation.valid) {
      ToastService.showError("Memory pressure alert", validation.message);
      return;
    }

    pluginApi.pluginSettings.recoveryThreshold = root.editRecoveryThreshold;
    pluginApi.saveSettings();
  }
}
~~~

- [ ] **Step 6: Run contract, logic, and QML validation**

Run:

~~~bash
node --test noctalia/plugins/memory-pressure-alert/logic.test.mjs noctalia/plugins/memory-pressure-alert/qml_contract.test.mjs
qmllint -I /etc/xdg/quickshell/noctalia-shell noctalia/plugins/memory-pressure-alert/Main.qml noctalia/plugins/memory-pressure-alert/AlertWindow.qml noctalia/plugins/memory-pressure-alert/Settings.qml
~~~

Expected: 12 tests pass and qmllint exits 0 with no output.

- [ ] **Step 7: Commit the working plugin**

~~~bash
git add noctalia/plugins/memory-pressure-alert/Main.qml noctalia/plugins/memory-pressure-alert/AlertWindow.qml noctalia/plugins/memory-pressure-alert/Settings.qml noctalia/plugins/memory-pressure-alert/qml_contract.test.mjs
git commit -m "feat(noctalia): add persistent memory pressure alerts"
~~~

---

### Task 3: Managed setup and health integration

**Files:**
- Modify: tests/setup_and_health.zsh
- Modify: setup.sh
- Modify: bin/dotfiles-health

**Interfaces:**
- Consumes: plugin directory created by Tasks 1 and 2.
- Produces: ~/.config/noctalia/plugins/memory-pressure-alert managed symlink.
- Produces: health failure for a missing, broken, or incorrect plugin link whenever ~/.config/noctalia exists.

- [ ] **Step 1: Add failing graphical setup and health tests**

Add these functions before the invocation list in tests/setup_and_health.zsh:

~~~zsh
test_setup_graphical_app_config_links_memory_alert() {
  local tmp
  tmp=$(make_tmpdir)
  trap 'rm -rf "$tmp"' EXIT
  mkdir -p "${tmp}/home" "${tmp}/config" "${tmp}/data"

  run_setup "$tmp" --link-only --only app-config >/dev/null

  local plugin_link="${tmp}/config/noctalia/plugins/memory-pressure-alert"
  [[ -L "$plugin_link" ]] || fail "expected linked memory pressure alert plugin"
  [[ "$(readlink "$plugin_link")" == \
      "${repo_root}/noctalia/plugins/memory-pressure-alert" ]] || \
    fail "expected memory alert plugin to point into the repository"

  rm -rf "$tmp"
  trap - EXIT
}

test_dotfiles_health_fails_wrong_memory_alert_link() {
  local tmp output exit_status
  tmp=$(make_tmpdir)
  trap 'rm -rf "$tmp"' EXIT
  mkdir -p "${tmp}/home" "${tmp}/config" "${tmp}/data"

  run_setup "$tmp" --link-only --headless >/dev/null
  run_setup "$tmp" --link-only --only app-config >/dev/null
  rm "${tmp}/config/noctalia/plugins/memory-pressure-alert"
  ln -s "${repo_root}/noctalia/plugins/wali-panel" \
    "${tmp}/config/noctalia/plugins/memory-pressure-alert"

  set +e
  output=$(
    HOME="${tmp}/home" \
      XDG_CONFIG_HOME="${tmp}/config" \
      XDG_DATA_HOME="${tmp}/data" \
      "${repo_root}/bin/dotfiles-health" --skip-systemd 2>&1
  )
  exit_status=$?
  set -e

  [[ "$exit_status" -ne 0 ]] || fail "health should reject the wrong memory alert link"
  [[ "$output" == *"wrong link target"* ]] || \
    fail "expected wrong memory alert link failure"

  rm -rf "$tmp"
  trap - EXIT
}
~~~

Add both calls before the final success print:

~~~zsh
test_setup_graphical_app_config_links_memory_alert
test_dotfiles_health_fails_wrong_memory_alert_link
~~~

- [ ] **Step 2: Run the focused setup tests and verify failure**

Run:

~~~bash
zsh tests/setup_and_health.zsh
~~~

Expected: FAIL with "expected linked memory pressure alert plugin".

- [ ] **Step 3: Add the managed setup link**

In setup_application_config_links in setup.sh, add the destination variable beside wali_panel_plugin:

~~~bash
local memory_alert_plugin="${noctalia_plugin_dir}/memory-pressure-alert"
~~~

Then add this line immediately after the wali-panel ln_s call:

~~~bash
ln_s "${DOTS_HOME}/noctalia/plugins/memory-pressure-alert" "$memory_alert_plugin"
~~~

- [ ] **Step 4: Add the conditional health check**

In bin/dotfiles-health, after the common config link loop and before stale-link checks, add:

~~~bash
if [[ -d "${XDG_CONFIG_HOME}/noctalia" ]]; then
    check_link \
        "${XDG_CONFIG_HOME}/noctalia/plugins/memory-pressure-alert" \
        "${DOTS_HOME}/noctalia/plugins/memory-pressure-alert"
fi
~~~

This condition keeps headless installations valid while making a present Noctalia configuration explicit and strict.

- [ ] **Step 5: Run setup, health, and shell validation**

Run:

~~~bash
zsh tests/setup_and_health.zsh
bash -n setup.sh
bash -n bin/dotfiles-health
shellcheck -e SC1091 setup.sh bin/dotfiles-health
~~~

Expected: setup and health tests pass; syntax checks and ShellCheck exit 0. SC1091 is excluded because both scripts deliberately source a repository path derived at runtime.

- [ ] **Step 6: Commit setup integration**

~~~bash
git add setup.sh bin/dotfiles-health tests/setup_and_health.zsh
git commit -m "feat(setup): install Noctalia memory alert"
~~~

---

### Task 4: Documentation, installation, and end-to-end verification

**Files:**
- Create: noctalia/plugins/memory-pressure-alert/README.md
- Modify: noctalia/noctalia.md

**Interfaces:**
- Consumes: the complete plugin and managed link.
- Produces: operator instructions for enablement, 80/90 adoption, optional 70/85 tuning, recovery, lock behavior, and smoke testing.

- [ ] **Step 1: Write the plugin README**

Create noctalia/plugins/memory-pressure-alert/README.md with:

~~~markdown
# Memory Pressure Alert

This headless Noctalia plugin shows a persistent memory warning on every screen.
It reuses Noctalia's System Monitor data and warning/critical thresholds.

## Behavior

- Warning and critical banners remain visible until memory recovers or they are dismissed.
- Dismissing a warning does not suppress a later critical escalation.
- Dismissing a critical alert suppresses the remainder of that episode.
- Warning recovery defaults to 65%.
- Critical recovery is five percentage points below critical, clamped to warning.
- Invalid threshold ordering shows a persistent, non-dismissible error banner.
- Polling pauses on Noctalia's lock screen; a crossing appears after unlock.

Displayed available memory reuses Noctalia's effective value. On ZFS systems,
that includes Noctalia's reclaimable-ARC adjustment rather than reporting raw
Linux `MemAvailable` as though no ARC adjustment occurred.

The plugin does not change Noctalia's current/default 80% warning and 90%
critical thresholds. To alert earlier, set 70% and 85% under Noctalia
Settings → System Monitor → Thresholds. This intentionally changes the bar
gauge colors at the same thresholds.

Open the plugin settings to change warning recovery. The process-monitor action
runs ghostty -e btop.
~~~

- [ ] **Step 2: Update the main Noctalia documentation**

Append this section to noctalia/noctalia.md:

~~~markdown
## Persistent memory-pressure alerts

The memory-pressure-alert plugin is installed through this managed link:

```text
~/.config/noctalia/plugins/memory-pressure-alert
  -> ~/d/dotfiles/noctalia/plugins/memory-pressure-alert
```

Enable it from Noctalia's Plugins settings. It is headless and does not add a
bar widget.

The plugin inherits the existing System Monitor memory thresholds. Installation
keeps the current/default 80% warning and 90% critical values, so it does not
silently retune the bar gauge. For earlier notification, explicitly choose 70%
warning and 85% critical in Settings → System Monitor → Thresholds; the gauge
and persistent banner will then change together.

Warning recovery is plugin-specific and defaults to 65%. Alerts are replicated
on every screen. Polling pauses on Noctalia's lock screen and refreshes after
unlock. Open btop launches ghostty -e btop.
~~~

- [ ] **Step 3: Run the complete automated verification suite**

Run:

~~~bash
node --test noctalia/plugins/memory-pressure-alert/logic.test.mjs noctalia/plugins/memory-pressure-alert/qml_contract.test.mjs
qmllint -I /etc/xdg/quickshell/noctalia-shell noctalia/plugins/memory-pressure-alert/Main.qml noctalia/plugins/memory-pressure-alert/AlertWindow.qml noctalia/plugins/memory-pressure-alert/Settings.qml
jq empty noctalia/plugins/memory-pressure-alert/manifest.json
just test
just check
~~~

Expected: 12 Node tests pass, QML and JSON checks exit 0, and every just test/check command passes.

- [ ] **Step 4: Install the managed link and refresh Noctalia**

Run:

~~~bash
./setup.sh --link-only --only app-config
test "$(realpath ~/.config/noctalia/plugins/memory-pressure-alert)" = \
  "$(realpath ~/d/dotfiles/noctalia/plugins/memory-pressure-alert)"
~~~

Expected: setup succeeds and the path-equivalence check exits 0.

Open Noctalia's Plugins settings, refresh plugin discovery, and enable Memory Pressure Alert. Per AGENTS.md, send an ohai notification before waiting for this user action.

- [ ] **Step 5: Perform the live smoke test without allocating memory**

Record the current System Monitor memory thresholds. In the UI, temporarily choose valid values around the current memory percentage so warning is entered first, then lower critical to enter critical. Verify:

1. The same banner appears on every connected screen.
2. Warning dismissal hides warning, but critical escalation reappears.
3. Values around critical do not downgrade until below the derived five-point recovery boundary.
4. Open btop creates a visible Ghostty window.
5. Dismissed critical remains hidden until warning recovery.
6. Equal warning/critical values produce a persistent configuration-error banner with no Dismiss action.
7. Correcting the values removes the error banner and resumes memory sampling.
8. A threshold crossing while locked appears on the first refreshed sample after unlock.

Restore recovery to 65 and restore either the original 80/90 values or the explicitly chosen 70/85 profile.

- [ ] **Step 6: Run final verification and inspect scope**

Run:

~~~bash
just verify
node --test noctalia/plugins/memory-pressure-alert/logic.test.mjs noctalia/plugins/memory-pressure-alert/qml_contract.test.mjs
qmllint -I /etc/xdg/quickshell/noctalia-shell noctalia/plugins/memory-pressure-alert/Main.qml noctalia/plugins/memory-pressure-alert/AlertWindow.qml noctalia/plugins/memory-pressure-alert/Settings.qml
git diff --check
git status --short
~~~

Expected: all commands pass. git status contains only the planned documentation files plus any pre-existing unrelated niri/familiar.kdl and ghostty/ changes.

- [ ] **Step 7: Commit documentation**

~~~bash
git add noctalia/noctalia.md noctalia/plugins/memory-pressure-alert/README.md
git commit -m "docs(noctalia): document memory pressure alerts"
~~~

- [ ] **Step 8: Request code review**

Use superpowers:requesting-code-review against the implementation commits. Resolve any findings with superpowers:receiving-code-review, rerun Step 6, and only then proceed to branch completion.
