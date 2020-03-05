Keith's dotfiles
================

Current setup
-------------

* [Arch Linux](https://www.archlinux.org/)
* [i3](https://i3wm.org/)
* [ZSH](http://www.zsh.org/)
* [termite](https://github.com/thestinger/termite)
* [rofi](https://github.com/davatorium/rofi)

Tools
 ----

* [Neovim](https://neovim.io/)
* compton 
* conda
* ag
* fasd
* fd
* feh
* lsd
* radian 
* ranger
* redshift
* py3status
* tmux
* visidata
* zathura
* zplugin

Installation
------------

To install, simply clone this repo and run `setup.sh`:

    git clone https://github.com/khughitt/dotfiles
    git submodule update --init --recursive
    cd dotfiles && ./setup.sh

Symbolic links will be created in $HOME to all of the major configuration files.

Configuration files are included for both Bash and Z shell. If you plan to use
Z shell, you will also want to install [zplugin](https://github.com/zdharma/zplugin).

Additional Z shell plugins I'm currently using:

 * [pure prompt](https://github.com/sindresorhus/pure)
 * [fzf-marks](https://github.com/urbainvaes/fzf-marks)
 * [zsh-nvm](https://github.com/lukechilds/zsh-nvm.git)
 * [zsh-completions](https://github.com/zsh-users/zsh-completions)

..And a bunch others. 

Screenshot
----------

![desktop screenshot](misc/2020-03-05_screenshot.png)

