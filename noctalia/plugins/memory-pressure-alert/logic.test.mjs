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
