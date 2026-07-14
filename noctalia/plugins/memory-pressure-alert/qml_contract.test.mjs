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
