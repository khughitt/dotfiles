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
    pluginApi && pluginApi.manifest && pluginApi.manifest.metadata
      ? pluginApi.manifest.metadata.defaultSettings || ({})
      : ({})
  property int editRecoveryThreshold:
    pluginApi && pluginApi.pluginSettings
      && pluginApi.pluginSettings.recoveryThreshold !== undefined
      && pluginApi.pluginSettings.recoveryThreshold !== null
      ? pluginApi.pluginSettings.recoveryThreshold
      : defaults.recoveryThreshold !== undefined
        && defaults.recoveryThreshold !== null
        ? defaults.recoveryThreshold
        : 65

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
    defaultValue: root.defaults.recoveryThreshold !== undefined
      && root.defaults.recoveryThreshold !== null
      ? root.defaults.recoveryThreshold
      : 65
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
