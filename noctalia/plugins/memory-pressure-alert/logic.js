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
