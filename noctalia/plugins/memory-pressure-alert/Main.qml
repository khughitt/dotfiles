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

  readonly property var defaults:
    pluginApi && pluginApi.manifest && pluginApi.manifest.metadata
      ? pluginApi.manifest.metadata.defaultSettings || ({})
      : ({})
  readonly property int recoveryThreshold:
    pluginApi && pluginApi.pluginSettings
      && pluginApi.pluginSettings.recoveryThreshold !== undefined
      && pluginApi.pluginSettings.recoveryThreshold !== null
      ? pluginApi.pluginSettings.recoveryThreshold
      : defaults.recoveryThreshold !== undefined
        && defaults.recoveryThreshold !== null
        ? defaults.recoveryThreshold
        : 65
  readonly property var monitorCommand:
    pluginApi && pluginApi.pluginSettings
      && pluginApi.pluginSettings.monitorCommand !== undefined
      && pluginApi.pluginSettings.monitorCommand !== null
      ? pluginApi.pluginSettings.monitorCommand
      : defaults.monitorCommand !== undefined
        && defaults.monitorCommand !== null
        ? defaults.monitorCommand
        : ["ghostty", "-e", "btop"]
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
