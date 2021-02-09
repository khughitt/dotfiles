Keith's dotfiles
================

Current setup
-------------

* [Arch Linux](https://www.archlinux.org/)
* [i3](https://i3wm.org/)
* [Zsh](http://www.zsh.org/)
* [kitty](https://sw.kovidgoyal.net/kitty/)
* [polybar](https://github.com/polybar/polybar)
* [rofi](https://github.com/davatorium/rofi)

Tools
-----

* [Neovim](https://neovim.io/)
* [picom](https://github.com/yshui/picom)
* [conda](https://docs.conda.io/en/latest/)
* [ag](https://github.com/ggreer/the_silver_searcher)
* [fasd](https://github.com/clvv/fasd)
* [fd](https://github.com/sharkdp/fd)
* [feh](https://feh.finalrewind.org/)
* [fzf](https://github.com/junegunn/fzf)
* [lsd](https://github.com/Peltoche/lsd)
* [radian](https://github.com/randy3k/radian)
* [nnn](https://github.com/jarun/nnn)
* [tmux](https://github.com/tmux/tmux/wiki)
* [visidata](https://www.visidata.org/)
* [zathura](https://pwmt.org/projects/zathura/)
* [zeit](https://github.com/mrusme/zeit)
* [zinit](https://github.com/zdharma/zinit)

Installation
------------

To install, simply clone this repo and run `setup.sh`:

    git clone https://github.com/khughitt/dotfiles
    git submodule update --init --recursive
    cd dotfiles && ./setup.sh

Symbolic links will be created in `$HOME` / `$XDG_CONFIG_DIR` to all of the major
configuration files.

Configuration files are included for both Bash and Z shell. If you plan to use
Z shell, you will also want to install [zinit](https://github.com/zdharma/zinit).

Additional Z shell plugins I'm currently using:

 * [pure prompt](https://github.com/sindresorhus/pure)
 * [zsh-nvm](https://github.com/lukechilds/zsh-nvm.git)
 * [zsh-completions](https://github.com/zsh-users/zsh-completions)

..And a bunch others. 

Screenshot
----------

![desktop screenshot](misc/2020-03-05_screenshot.png)
