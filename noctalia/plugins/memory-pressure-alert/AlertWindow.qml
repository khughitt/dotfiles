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
    Math.max(320, (screen && screen.width ? screen.width : 640) - Style.marginXL * 2)
  ) + shadowPadding * 2
  implicitHeight: banner.implicitHeight + shadowPadding * 2
  color: "transparent"

  anchors.top: true
  margins.top: {
    const screenName = screen && screen.name ? screen.name : "";
    const barAtTop = Settings.getBarPositionForScreen(screenName) === "top";
    return barAtTop
      ? Style.getBarHeightForScreen(screenName) + Style.marginM
      : Style.marginL;
  }

  WlrLayershell.namespace:
    "noctalia-memory-pressure-alert-" + (screen && screen.name ? screen.name : "unknown")
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
