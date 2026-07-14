Keith's dotfiles
================

Current setup
-------------

* [Arch Linux](https://www.archlinux.org/)
* [Niri](https://niri-wm.github.io/)
* [Noctalia](https://github.com/noctalia-dev/noctalia-shell)
* [Zsh](http://www.zsh.org/)
* [kitty](https://sw.kovidgoyal.net/kitty/)

Tools
-----

* [bat](https://github.com/sharkdp/bat)
* [btop](https://github.com/aristocratos/btop)
* [dust](https://github.com/bootandy/dust)
* [fasd](https://github.com/clvv/fasd)
* [fd](https://github.com/sharkdp/fd)
* [feh](https://feh.finalrewind.org/)
* [fzf](https://github.com/junegunn/fzf)
* [lsd](https://github.com/Peltoche/lsd)
* [micromamba](https://mamba.readthedocs.io/en/latest/user_guide/micromamba.html)
* [moor](https://github.com/walles/moor)
* [neovim](https://neovim.io/)
* [radian](https://github.com/randy3k/radian)
* [rg](https://github.com/BurntSushi/ripgrep)
* [sd](https://github.com/chmln/sd)
* [tmux](https://github.com/tmux/tmux/wiki)
* [tre](https://github.com/dduan/tre)
* [visidata](https://www.visidata.org/)
* [zathura](https://pwmt.org/projects/zathura/)
* [zinit](https://github.com/zdharma/zinit)

Installation
------------

To install, clone this repo and run `setup.sh`:

    git clone https://github.com/khughitt/dotfiles
    cd dotfiles && ./setup.sh

Symbolic links will be created in `$HOME` / `$XDG_CONFIG_DIR` to all of the major
configuration files.

For a safe preview of the headless link setup:

    just setup-dry-run

For a link-only setup that skips package installation and external clones:

    ./setup.sh --link-only --headless

`setup.sh` can also run selected phases. This is useful when refreshing a small
piece of the setup after a change:

    ./setup.sh --dry-run --link-only --headless --only shell,systemd
    just setup-only shell,systemd

Valid phases are:

    external-clones shell gtk graphical-config common-config systemd kitty home app-config mime tmux packages

To install the systemd user timer that keeps high-flux Dropbox folders ignored:

    ./setup.sh --link-only --headless --only systemd --enable-user-timers

The timer runs `dropbox_ignore_flux` periodically. It sets Dropbox's
`com.dropbox.ignored` attribute on common high-churn directories such as
`node_modules`, `.venv`, `.worktrees`, `.snakemake`, and `__pycache__`.

Configuration files are included for both Bash and Z shell. If you plan to use
Z shell, you will also want to install [zinit](https://github.com/zdharma/zinit).

Additional Z shell plugins I'm currently using:

 * [pure prompt](https://github.com/sindresorhus/pure)
 * [zsh-nvm](https://github.com/lukechilds/zsh-nvm.git)
 * [zsh-completions](https://github.com/zsh-users/zsh-completions)

..And a bunch others. 

Commands
--------

Common maintenance commands are wrapped in `just`:

```
just check          # run shell syntax, shellcheck, and modeline checks
just test           # run focused zsh tests
just health         # check links and local setup without querying systemd state
just health-systemd # include systemd user timer state
just setup-dry-run  # preview headless link-only setup
just setup-only ... # preview selected setup phases, e.g. shell,systemd
just verify         # run check, test, and health
```

`bin/dotfiles-health` verifies required tools, important managed symlinks,
shell sourceability, Dropbox ignore timer links, and stale config links that
were intentionally removed from setup management.

Aliases / Functions
-------------------

Not a complete list, but some useful ones..

```
j       # jump (fasd)
l       # ls -l
lr      # ls -latr
y       # yay

..      # cd ..
cpr     # cp -r
rmf     # rm -fr

c       # open cheatsheet
C       # open config

doc     # docker
docc    # docker compose
up      # bring up compose stack
down    # bring down compose stack

g       # git
gst     # git status
gcam    # git commit -am
gcmsg   # git commit -m
gco     # git checkout
gp      # git push
grst    # git restore --staged

h ..    # search history
pg ..   # search ps

rgl     # rg -l
rgu     # rg -uuu
fda     # fd -Luu

v       # nvim recent
vl      # nvim last
vr      # rg -> nvim
```

Screenshot
----------

![desktop screenshot](misc/2020-03-05_screenshot.png)
