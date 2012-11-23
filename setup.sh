#!/bin/sh

# Choose shell
read -p "Select a shell to use [bash/zsh]: " SH
if [ "$SH" != "bash" ] && [ "$SH" != "zsh" ]; then
    echo "Invalid choice. Exiting..."
    exit;
fi

# Checks for file or directory and creates a sym link if it 
# doesn't already exist
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

# Terminator
if [ ! -e ~/.config/terminator ]; then
    mkdir -p ~/.config/terminator
fi
ln_s ${PWD}/terminator ~/.config/terminator/config

# IPython
if [! -e $XDG_CONFIG_HOME/ipython]; then
    ipython profile create
    
    for filename in "ipython_config.py" "ipython_notebook_config.py" "ipython_qtconsole_config.py"; do
        SOURCE=${PWD}/ipython/${filename}
        DEST=$XDG_CONFIG_HOME/ipython/profile_default/${filename}
        
        rm $DEST
        ln_s $SOURCE $DEST

    cp ${PWD}/ipython/autojump_ipython.py $XDG_CONFIG_HOME/ipython/profile_default/startup
else
    echo "[SKIPPING] Ipython (already exists...)"
fi

# Everything else
for path in "devilspie" "conky" "conkyrc" "gitconfig", "gitignore_global", "Rprofile" "vim" "vimrc" "Xdefaults"; do
    ln_s ${PWD}/${path} ~/.${path}
done

echo "Done!"

