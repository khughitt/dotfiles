import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Modules.Bar.Extras
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
  readonly property bool showAgentStatus: widgetSettings.showAgentStatus !== undefined
    ? widgetSettings.showAgentStatus
    : (defaultSettings.showAgentStatus !== undefined ? defaultSettings.showAgentStatus : true)
  readonly property real barHeight: Style.getBarHeightForScreen(screenName)
  readonly property real capsuleHeight: Style.getCapsuleHeightForScreen(screenName)
  readonly property real barFontSize: Style.getBarFontSizeForScreen(screenName)
  readonly property real cellSize: Style.toOdd(capsuleHeight * 0.72)

  property var profiles: []
  property string loadError: "loading"
  property var cells: []
  property var agents: ({})
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

  function windowIndexSnapshot() {
    var idx = {};
    for (var i = 0; i < CompositorService.windows.count; i++) {
      var w = CompositorService.windows.get(i);
      if (w && w.id !== undefined && w.workspaceId !== undefined) {
        idx[w.id] = w.workspaceId;
      }
    }
    return idx;
  }

  function refreshCells() {
    var filtered = Logic.filterWorkspaces(root.workspaceSnapshot(), {
      screenName: root.screenName,
      focusedOutput: root.focusedOutput(),
      globalWorkspaces: CompositorService.globalWorkspaces,
      followFocusedScreen: root.followFocusedScreen,
      hideUnoccupied: root.hideUnoccupied
    });
    var cells = Logic.buildCells(filtered, root.profiles);
    if (root.showAgentStatus) {
      cells = Logic.rollupAgents(cells, root.agents, root.windowIndexSnapshot());
    }
    root.cells = cells;
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

  function applyAgentsText(text) {
    var result = Logic.parseAgents(text);
    root.agents = result.agents;
    if (result.error && result.error !== "empty") {
      Logger.w("WorkspaceProfilesBar", "agents.json parse issue:", result.error);
    }
    root.scheduleRefresh();
  }

  function clearAgents(errorText) {
    root.agents = ({});
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
  onShowAgentStatusChanged: scheduleRefresh()

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

  FileView {
    id: agentsView
    path: Quickshell.env("HOME") + "/.local/state/ohai/agents.json"
    blockLoading: true
    watchChanges: true
    onFileChanged: {
      this.reload();
    }
    onLoaded: {
      agentsRetryTimer.running = false;
      root.applyAgentsText(agentsView.text());
    }
    onLoadFailed: {
      root.clearAgents("load failed: " + agentsView.path);
      agentsRetryTimer.running = true;
    }
  }

  Timer {
    id: agentsRetryTimer
    interval: 3000
    repeat: true
    running: false
    onTriggered: agentsView.reload()
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

        Rectangle {
          id: statusDot
          visible: root.showAgentStatus && !!cellItem.cell.agentStatus
          width: Math.max(4, Math.round(root.cellSize * 0.3))
          height: width
          radius: width / 2
          anchors.right: pill.right
          anchors.top: pill.top
          anchors.rightMargin: 1
          anchors.topMargin: 1
          color: cellItem.cell.agentStatus === "waiting" ? Color.mError : Color.mPrimary
          opacity: cellItem.cell.agentStatus === "waiting" ? Style.opacityFull : Style.opacityMedium

          Behavior on opacity {
            NumberAnimation {
              duration: Style.animationFast
              easing.type: Easing.InOutCubic
            }
          }
        }
      }
    }
  }
}
