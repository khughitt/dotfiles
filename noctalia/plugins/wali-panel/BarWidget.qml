import QtQuick
import Quickshell
import qs.Commons
import qs.Services.UI
import qs.Widgets

NIconButton {
  id: root

  property ShellScreen screen
  property var pluginApi: null

  property string widgetId: ""
  property string section: ""
  property int sectionWidgetIndex: -1
  property int sectionWidgetsCount: 0

  property var widgetMetadata: BarWidgetRegistry.widgetMetadata[widgetId]
  readonly property string screenName: screen ? screen.name : ""
  readonly property string iconColorKey: widgetMetadata && widgetMetadata.iconColor ? widgetMetadata.iconColor : "primary"

  baseSize: Style.getCapsuleHeightForScreen(screenName)
  applyUiScale: false
  customRadius: Style.radiusL
  icon: "wallpaper-selector"
  tooltipText: pluginApi && pluginApi.panelOpenScreen === screen ? "" : "Wallpaper actions"
  tooltipDirection: BarService.getTooltipDirection(screenName)
  colorBg: Style.capsuleColor
  colorFg: Color.resolveColorKey(iconColorKey)
  border.color: Style.capsuleBorderColor
  border.width: Style.capsuleBorderWidth

  onClicked: {
    if (pluginApi) {
      pluginApi.togglePanel(screen, root);
    }
  }
}
