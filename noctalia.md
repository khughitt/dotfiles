# Noctalia

## Local plugins

Running `./setup.sh` in graphical mode installs the local `wali-panel` plugin by symlinking:

`noctalia/plugins/wali-panel` -> `~/.config/noctalia/plugins/wali-panel`

Noctalia will discover the plugin from disk on startup or plugin refresh. If the widget does not appear yet, open Plugins settings in Noctalia and enable `wali-panel`.

The plugin expects `~/bin/walictl` to exist, which is provided by the existing top-level `bin` symlink created by `setup.sh`.
