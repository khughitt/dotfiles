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

  // --- Actions -------------------------------------------------------------

  // A null stderr parser would close the channel, so wsprofilectl failures would
  // vanish. Collect stderr and forward it to the qs log for manual check 9.
  Process {
    id: ctl
    stderr: StdioCollector {
      onStreamFinished: {
        if (this.text.length > 0) console.error("wsprofile-menu: wsprofilectl:", this.text);
      }
    }
    onExited: function(exitCode) {
      var stderrText = String(ctl.stderr.text || "").trim();
      if (exitCode !== 0) {
        console.error("wsprofile-menu: wsprofilectl exited " + exitCode
          + (stderrText.length > 0 ? ": " + stderrText : " with no stderr"));
      }
    }
  }
  Process { id: editorProc }

  function runCtl(verb, id) {
    ctl.running = false;
    ctl.command = ["node",
      Quickshell.env("HOME") + "/d/dotfiles/wsprofiles/bin/wsprofilectl", verb, id];
    ctl.running = true;
  }

  function openEditor() {
    var editor = Quickshell.env("EDITOR");
    if (!editor || editor.length === 0) editor = "nano";
    var file = Quickshell.env("HOME") + "/d/dotfiles/wsprofiles/profiles.yaml";
    editorProc.running = false;
    // Launch the editor through sh so EDITOR values that carry flags (e.g.
    // "nvim -u NONE") word-split correctly; the file is passed as "$1" so the
    // path itself is never re-split. This shell is intentional, for this path only.
    editorProc.command = ["kitty", "sh", "-c", editor + ' "$1"', "sh", file];
    // The editor should survive quickshell reloads/menu restarts while the user is
    // editing profiles.yaml.
    editorProc.startDetached();
  }

  function dispatch(action) {
    if (!action) return;
    if (action.type === "hide") { root.shown = false; return; }
    if (action.type === "move") { root.highlight = action.highlight; return; }
    if (action.type === "editor") { root.openEditor(); root.shown = false; return; }
    if (action.type === "open" || action.type === "new") {
      root.runCtl(action.type, action.id);
      root.shown = false;
    }
  }

  // --- Qt key event -> normalized key --------------------------------------

  function normKey(event) {
    switch (event.key) {
      case Qt.Key_Escape: return "Escape";
      case Qt.Key_Return:
      case Qt.Key_Enter: return "Enter";
      case Qt.Key_Up: return "Up";
      case Qt.Key_Down: return "Down";
      case Qt.Key_Tab:
      case Qt.Key_Backtab: return "Tab";
      case Qt.Key_1: return "1";
      case Qt.Key_2: return "2";
      case Qt.Key_3: return "3";
      case Qt.Key_4: return "4";
      case Qt.Key_5: return "5";
      case Qt.Key_6: return "6";
      case Qt.Key_7: return "7";
      case Qt.Key_8: return "8";
      case Qt.Key_9: return "9";
    }
    if (event.text === "+") return "+";
    return null;
  }

  function handleKey(event) {
    var key = root.normKey(event);
    if (key === null) return;
    event.accepted = true;
    if (!root.modelReady && key !== "Escape" && key !== "+") return;
    var action = Logic.keyToAction(
      key,
      { shift: (event.modifiers & Qt.ShiftModifier) !== 0 },
      { profiles: root.profiles, highlight: root.highlight });
    root.dispatch(action);
  }

  onShownChanged: {
    if (root.shown) {
      root.beginModelReload();
      // Re-read fresh from disk; onLoaded/onLoadFailed update the model. Avoid
      // parsing text() directly here, which can be stale mid-reload.
      catalogView.reload();
      keyCatcher.forceActiveFocus();
    }
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

    Item {
      id: keyCatcher
      anchors.fill: parent
      focus: true
      Keys.onPressed: (event) => root.handleKey(event)
    }

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

            MouseArea {
              anchors.fill: parent
              hoverEnabled: true
              onEntered: root.highlight = index
              onClicked: root.dispatch({ type: "open", id: modelData.id })
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

          MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onEntered: root.highlight = root.profiles.length
            onClicked: root.dispatch({ type: "editor" })
          }
        }

        // Footer hint.
        Text {
          topPadding: 6
          text: "1-9 switch | Shift+1-9 new instance | + add | Esc close"
          color: "#6c7086"; font.pixelSize: 11
        }
      }
    }
  }
}
