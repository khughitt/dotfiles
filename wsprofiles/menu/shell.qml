import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "menu-logic.js" as Logic

ShellRoot {
  id: root
  property bool shown: false
  property var profiles: []
  property string loadError: "loading"
  property int highlight: 0
  property bool modelReady: false

  function applyModel() {
    var res = Logic.parseProfiles(catalogView.text());
    root.profiles = res.profiles;
    root.loadError = res.error ? res.error : "";
    root.modelReady = root.loadError === "";
    root.highlight = Logic.clampHighlight(root.highlight, root.profiles.length);
  }

  function beginModelReload() {
    // FileView.text() can return the previous contents while reload() is pending.
    // Clear the dispatchable model first so a fast keypress after opening cannot
    // act on stale profile ids.
    root.profiles = [];
    root.loadError = "loading";
    root.modelReady = false;
    root.highlight = 0;
  }

  IpcHandler {
    target: "menu"
    function toggle(): void { root.shown = !root.shown }
    function show(): void { root.shown = true }
    function hide(): void { root.shown = false }
  }

  FileView {
    id: catalogView
    path: Quickshell.env("HOME") + "/.config/niri/wsprofiles.json"
    blockLoading: true
    watchChanges: true
    onFileChanged: {
      root.beginModelReload();
      this.reload();
    }
    onLoaded: root.applyModel()
    // On I/O failure (missing file) set the error state directly. Do NOT parse
    // text() here - it can still hold previously-loaded content during a reload,
    // which would render stale profiles instead of the error state.
    onLoadFailed: {
      root.profiles = [];
      root.loadError = "load failed";
      root.modelReady = false;
      root.highlight = 0;
    }
  }

  // The initial load is driven by FileView's preload firing onLoaded/onLoadFailed;
  // no Component.onCompleted parse is needed (and it would risk a stale read).

  PanelWindow {
    id: win
    visible: root.shown
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "wsprofile-menu"
    WlrLayershell.keyboardFocus: root.shown ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    anchors { top: true; bottom: true; left: true; right: true }

    // Click-outside dismiss.
    MouseArea {
      anchors.fill: parent
      onClicked: root.shown = false
    }

    Rectangle {
      id: card
      anchors.centerIn: parent
      width: 420
      radius: 14
      color: "#1e1e2e"
      border.color: "#45475a"
      border.width: 1
      height: content.implicitHeight + 24

      // Swallow clicks inside the card so they don't dismiss.
      MouseArea { anchors.fill: parent }

      Column {
        id: content
        x: 12; y: 12
        width: parent.width - 24
        spacing: 2

        Text {
          text: "Workspace Profiles"
          color: "#9399b2"
          font.pixelSize: 12
          bottomPadding: 6
        }

        // Error state.
        Text {
          visible: root.loadError !== "" && root.loadError !== "loading"
          text: "No profiles - is wsprofiled running?"
          color: "#f38ba8"
          font.pixelSize: 14
          height: 40
          verticalAlignment: Text.AlignVCenter
        }

        // Loading state. Briefly visible when the menu opens and FileView reloads.
        Text {
          visible: root.loadError === "loading"
          text: "Loading profiles..."
          color: "#9399b2"
          font.pixelSize: 14
          height: 40
          verticalAlignment: Text.AlignVCenter
        }

        // Profile rows.
        Repeater {
          model: root.modelReady ? root.profiles : []
          delegate: Rectangle {
            required property var modelData
            required property int index
            width: content.width
            height: 40
            radius: 8
            color: index === root.highlight ? "#313244" : "transparent"

            Row {
              anchors.fill: parent
              anchors.leftMargin: 8
              spacing: 10

              // Accent bar in the ring color when highlighted.
              Rectangle {
                width: 3; height: 24; radius: 2
                anchors.verticalCenter: parent.verticalCenter
                color: modelData.ring
                visible: index === root.highlight
              }
              // Ring-color swatch.
              Rectangle {
                width: 16; height: 16; radius: 4
                anchors.verticalCenter: parent.verticalCenter
                color: modelData.ring
              }
              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: index < 9 ? (index + 1).toString() : ""
                color: "#bac2de"; font.pixelSize: 14; width: 14
              }
              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: modelData.icon
                color: modelData.ring; font.pixelSize: 16
              }
              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: modelData.label
                color: "#cdd6f4"; font.pixelSize: 14
              }
            }
          }
        }

        // "+ new" row.
        Rectangle {
          width: content.width
          height: 40
          radius: 8
          color: root.highlight === root.profiles.length ? "#313244" : "transparent"
          Row {
            anchors.fill: parent
            anchors.leftMargin: 8
            spacing: 10
            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: "+"; color: "#9399b2"; font.pixelSize: 16; leftPadding: 19
            }
            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: "new profile..."; color: "#9399b2"; font.pixelSize: 14
            }
          }
        }

        // Footer hint.
        Text {
          topPadding: 6
          text: "1-9 switch | Shift+N new instance | + add | Esc close"
          color: "#6c7086"; font.pixelSize: 11
        }
      }
    }
  }
}
