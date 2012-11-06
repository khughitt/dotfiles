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

# Everything else
for path in "devilspie" "conky" "conkyrc" "gitconfig" "Rprofile" "vim" "vimrc" "Xdefaults"; do
    ln_s ${PWD}/${path} ~/.${path}
done

echo "Done!"

