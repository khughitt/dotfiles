import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI
import qs.Widgets

Item {
  id: root

  property var pluginApi: null

  property bool allowAttach: true
  property real contentPreferredWidth: Math.round(560 * Style.uiScaleRatio)
  property real contentPreferredHeight: Math.round(760 * Style.uiScaleRatio)

  property string helperPath: Quickshell.env("HOME") + "/bin/walictl"
  property bool loading: false
  property bool actionRunning: false
  property string errorMessage: ""
  property var wallpaper: ({})
  property string pendingAction: ""

  readonly property bool hasWallpaper: wallpaper && wallpaper.ok === true
  readonly property string sourcePath: hasWallpaper ? (wallpaper.source_wallpaper_path || "") : ""
  readonly property string previewPath: {
    if (!hasWallpaper) {
      return "";
    }
    return wallpaper.source_wallpaper_path || wallpaper.current_wallpaper_path || "";
  }
  readonly property string previewSource: previewPath !== "" ? "file://" + previewPath : ""
  readonly property string displayDate: hasWallpaper ? (wallpaper.display_date || "") : ""

  function normalizeMessage(message, fallbackMessage) {
    var text = (message || "").trim();
    return text !== "" ? text : fallbackMessage;
  }

  function elideMiddle(text, maxLength) {
    if (!text || text.length <= maxLength) {
      return text || "";
    }

    var keep = Math.max(8, Math.floor((maxLength - 1) / 2));
    return text.slice(0, keep) + "..." + text.slice(text.length - keep);
  }

  function resetWallpaperState() {
    wallpaper = ({});
  }

  function loadWallpaper() {
    if (currentWallpaperProcess.running) {
      return;
    }

    loading = true;
    errorMessage = "";
    resetWallpaperState();
    currentWallpaperProcess.running = true;
  }

  function runAction(actionName) {
    if (actionRunning || loading || !hasWallpaper) {
      return;
    }

    var needsSource = (actionName === "save-current" || actionName === "edit-current");
    if (needsSource && sourcePath === "") {
      return;
    }

    pendingAction = actionName;
    actionRunning = true;
    actionProcess.running = true;
  }

  function handleActionSuccess(actionName) {
    if (actionName === "save-current") {
      ToastService.showNotice("Wallpaper", "Saved current wallpaper to favorites.", "heart");
    } else if (actionName === "edit-current") {
      ToastService.showNotice("Wallpaper", "Opened current wallpaper in GIMP.", "wallpaper-selector");
    } else if (actionName === "forward" || actionName === "backward" || actionName === "random") {
      root.loadWallpaper();
    }
  }

  function copySourcePath() {
    if (!hasWallpaper || sourcePath === "") {
      return;
    }

    copyProcess.running = true;
  }

  Component.onCompleted: {
    loadWallpaper();
  }

  Connections {
    target: pluginApi ? pluginApi : null

    function onPanelOpenScreenChanged() {
      if (pluginApi && pluginApi.panelOpenScreen) {
        root.loadWallpaper();
      }
    }
  }

  Process {
    id: currentWallpaperProcess

    running: false
    command: [root.helperPath, "current", "--json"]
    stdout: StdioCollector {}
    stderr: StdioCollector {}

    onExited: function(exitCode) {
      root.loading = false;
      var stdoutText = String(currentWallpaperProcess.stdout.text || "");
      var stderrText = String(currentWallpaperProcess.stderr.text || "");

      if (exitCode !== 0) {
        root.errorMessage = root.normalizeMessage(stderrText, "Failed to load current wallpaper.");
        root.resetWallpaperState();
        return;
      }

      try {
        var payload = JSON.parse(stdoutText.trim());
        if (!payload.ok) {
          root.errorMessage = "walictl returned an invalid wallpaper payload.";
          root.resetWallpaperState();
          return;
        }

        root.wallpaper = payload;
        root.errorMessage = "";
      } catch (error) {
        root.errorMessage = root.normalizeMessage(error && error.message ? error.message : "", "Failed to parse walictl output.");
        root.resetWallpaperState();
      }
    }
  }

  Process {
    id: actionProcess

    running: false
    command: root.pendingAction !== "" ? [root.helperPath, root.pendingAction] : []
    stdout: StdioCollector {}
    stderr: StdioCollector {}

    onExited: function(exitCode) {
      var actionName = root.pendingAction;
      var stderrText = String(actionProcess.stderr.text || "");

      root.pendingAction = "";
      root.actionRunning = false;

      if (exitCode !== 0) {
        ToastService.showError("Wallpaper", root.normalizeMessage(stderrText, "Wallpaper action failed."));
        return;
      }

      root.handleActionSuccess(actionName);
    }
  }

  Process {
    id: copyProcess

    running: false
    command: ["wl-copy", root.sourcePath]

    onExited: function(exitCode) {
      if (exitCode === 0) {
        ToastService.showNotice("Wallpaper", "Path copied to clipboard.", "clipboard");
      } else {
        ToastService.showError("Wallpaper", "Failed to copy path to clipboard.");
      }
    }
  }

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: Style.marginL
    spacing: Style.marginL

    NHeader {
      label: "Wallpaper"
      description: "Preview the current wallpaper source and run common wali actions."
    }

    NBox {
      Layout.fillWidth: true
      Layout.fillHeight: true
      forceOpaque: true

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: Style.marginL
        spacing: Style.marginL

        NImageRounded {
          Layout.alignment: Qt.AlignHCenter
          Layout.preferredWidth: Math.min(root.contentPreferredWidth - (Style.marginL * 4), 512 * Style.uiScaleRatio)
          Layout.preferredHeight: Math.min(root.contentPreferredHeight * 0.55, 512 * Style.uiScaleRatio)
          radius: Style.radiusM
          borderWidth: Style.borderS
          borderColor: Style.boxBorderColor
          imagePath: root.previewSource
          fallbackIcon: root.loading ? "loader" : "wallpaper-selector"
          fallbackIconSize: Style.fontSizeXXL
          imageFillMode: Image.PreserveAspectFit
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: Style.marginS

          NText {
            text: root.loading ? "Loading current wallpaper..." : "Current wallpaper source"
            pointSize: Style.fontSizeL
            font.weight: Style.fontWeightSemiBold
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
          }

          NText {
            visible: !root.loading && root.errorMessage !== ""
            text: root.errorMessage
            color: Color.mError
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
          }

          NText {
            visible: !root.loading && root.errorMessage === "" && root.displayDate !== ""
            text: "Date: " + root.displayDate
            color: Color.mOnSurfaceVariant
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
          }

          NText {
            visible: !root.loading && root.errorMessage === "" && root.sourcePath !== ""
            text: "Source: " + root.elideMiddle(root.sourcePath, 84)
            color: Color.mOnSurfaceVariant
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
          }

          NText {
            visible: !root.loading && root.errorMessage === "" && root.sourcePath === ""
            text: "No source wallpaper path is available for the current wallpaper."
            color: Color.mOnSurfaceVariant
            wrapMode: Text.WordWrap
            Layout.fillWidth: true
          }
        }

        RowLayout {
          Layout.alignment: Qt.AlignHCenter
          spacing: Style.marginM

          NIconButton {
            icon: "arrow-left"
            tooltipText: "Previous wallpaper"
            enabled: root.hasWallpaper && !root.loading && !root.actionRunning
            onClicked: root.runAction("backward")
          }

          NIconButton {
            icon: "arrow-right"
            tooltipText: "Next wallpaper"
            enabled: root.hasWallpaper && !root.loading && !root.actionRunning
            onClicked: root.runAction("forward")
          }

          NIconButton {
            icon: "dice"
            tooltipText: "Random wallpaper"
            enabled: root.hasWallpaper && !root.loading && !root.actionRunning
            onClicked: root.runAction("random")
          }

          NIconButton {
            icon: "heart"
            tooltipText: "Save to favorites"
            enabled: root.hasWallpaper && root.sourcePath !== "" && !root.loading && !root.actionRunning
            onClicked: root.runAction("save-current")
          }

          NIconButton {
            icon: "photo-edit"
            tooltipText: "Edit in GIMP"
            enabled: root.hasWallpaper && root.sourcePath !== "" && !root.loading && !root.actionRunning
            onClicked: root.runAction("edit-current")
          }

          NIconButton {
            icon: "clipboard"
            tooltipText: "Copy source path"
            enabled: root.hasWallpaper && root.sourcePath !== "" && !root.loading
            onClicked: root.copySourcePath()
          }
        }

        Item {
          Layout.fillHeight: true
        }
      }
    }
  }
}
