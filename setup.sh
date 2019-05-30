#!/bin/bash

# Choose shell
read -p "Select a shell to use [bash/zsh]: " SH
if [ "$SH" != "bash" ] && [ "$SH" != "zsh" ]; then
    echo "Invalid choice. Exiting..."
    exit;
fi

# Check for configuration directory
if [ -z $XDG_CONFIG_HOME ]; then
    XDG_CONFIG_HOME=$HOME/.config
fi
mkdir -p $XDG_CONFIG_HOME

# Checks for file or directory and creates a sym link if it doesn't already exist
function ln_s() {
    if [ -e $2 ]; then
        echo "[SKIPPING] \"$2\" (already exists...)"
    else
        echo "[CREATING] \"$2\""
        ln -s $1 $2
    fi
}

echo "Setting up dotfiles..."

# Setup shell
ln_s ${PWD}/${SH}rc ~/.${SH}rc
ln_s ${PWD}/shell ~/.shell

# Create needed directories
for dir in "compton" "gedit" "i3" "i3status" "sway" "rofi" "termite"; do
    mkdir -p ${XDG_CONFIG_HOME}/${dir}
done

# Gedit
cp -r ${PWD}/gedit/styles ${XDG_CONFIG_HOME}/gedit/

# Gtk 3.0
if [ ! -e ${XDG_CONFIG_HOME}/gtk-3.0/ ]; then
    mkdir ${XDG_CONFIG_HOME}/gtk-3.0/
fi
ln -s ${PWD}/gtkrc-3.0 ${XDG_CONFIG_HOME}/gtk-3.0/settings.ini

# ~/.config/xx
for path in "termcolors" "colorls" "mimeapps.list" "redshift.conf"  \
            "labnote" "pylintrc" "ranger"; do
    ln_s ${PWD}/${path} ${XDG_CONFIG_HOME}/${path}
done

# ~/.xx
for path in "agignore" "ansiweather" "ctags" "dir_colors" "gitconfig" \
            "gitignore_global" "Rprofile" "Renviron" "tmux" "tmux.conf" \
            "vim" "vimrc" "visidatarc" "xinitrc" "xmodmaprc" "Xresources" \
	        "xprofile"; do
    ln_s ${PWD}/${path} ~/.${path}
done

# ~/.config/xx/config
for path in "i3" "i3status" "sway" "rofi" "termite"; do
    ln_s ${PWD}/${path} ${XDG_CONFIG_HOME}/${path}/config
done

# compton
ln -s ${PWD}/compton.conf ${XDG_CONFIG_HOME}/compton/compton.conf

# Copy Xresources to Xdefaults for sway
ln_s ${PWD}/Xresources ~/.Xdefaults

# scripts, etc.
ln -s ${PWD}/bin ~/

# Vim temp dirs
mkdir -p ~/.vim/tmp/backup
mkdir -p ~/.vim/tmp/yankring

# Mimetypes
mkdir -p ~/.local/share/mime
ln -s mime ~/.local/share/mime/packages
update-mime-database ~/.local/share/mime

# Install oh-my-zsh
if [ "$SH" == "zsh" ]; then
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)" 

    # install biozsh
    git clone https://github.com/kloetzl/biozsh.git \
        ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/biozsh 

    # install zsh-nvm
    git clone https://github.com/lukechilds/zsh-nvm.git \
        ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-nvm 

    # install git-auto-status
    mkdir ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/git-auto-status
    wget https://gist.githubusercontent.com/oshybystyi/475ee7768efc03727f21/raw/4bfd57ef277f5166f3070f11800548b95a501a19/git-auto-status.plugin.zsh \
        -O ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/git-auto-status/git-auto-status.plugin.zsh

fi

# rvm
while
  read -r -p "Install RVM? [yes|no]" response &&
    [[ $response =~ ^([yY][eE][sS]|[yY])$ ]]
do
    echo "Adding rvm gpg key..."
    gpg --keyserver hkp://pool.sks-keyservers.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB

    echo "Installing rvm..."
    \curl -sSL https://get.rvm.io | bash
done

echo "Done!"
echo "Don't forget to install any necessary fonts, icons, etc."

