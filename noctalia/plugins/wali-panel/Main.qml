import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI

Item {
  id: root

  property var pluginApi: null

  function normalizeScreen(screenName) {
    var text = String(screenName || "").trim();
    return text === "" || text === "all" ? undefined : text;
  }

  function primaryScreenName() {
    return Quickshell.screens.length > 0 ? Quickshell.screens[0].name : "";
  }

  function updateBaselineForScreen(screenName, indexKey) {
    if (!screenName) {
      return;
    }

    var wallpaperList = WallpaperService.getWallpapersList(screenName);
    if (!wallpaperList || wallpaperList.length === 0) {
      return;
    }

    var currentWallpaper = WallpaperService.getWallpaper(screenName) || "";
    var foundIndex = wallpaperList.indexOf(currentWallpaper);
    if (foundIndex < 0) {
      return;
    }

    var indices = Object.assign({}, WallpaperService.alphabeticalIndices || {});
    indices[indexKey] = foundIndex;
    WallpaperService.alphabeticalIndices = indices;
  }

  function updateAlphabeticalBaseline(screenName) {
    if (Settings.data.wallpaper.enableMultiMonitorDirectories) {
      if (screenName) {
        updateBaselineForScreen(screenName, screenName);
        return;
      }

      for (var i = 0; i < Quickshell.screens.length; i++) {
        var currentScreenName = Quickshell.screens[i].name;
        updateBaselineForScreen(currentScreenName, currentScreenName);
      }
      return;
    }

    updateBaselineForScreen(screenName || primaryScreenName(), "all");
  }

  IpcHandler {
    target: "plugin:wali-panel"

    function random(screen: string): string {
      if (!Settings.data.wallpaper.enabled) {
        return "disabled";
      }

      var targetScreen = root.normalizeScreen(screen);
      WallpaperService.setRandomWallpaper(targetScreen);
      root.updateAlphabeticalBaseline(targetScreen);
      return "ok";
    }
  }
}
