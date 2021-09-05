#!/bin/zsh
#
# rofi tasks launcher
# kh (jan 2021)
#
tasks=(abstract-algebra bayes complexity dsp gen-art gene-sets l-systems shaders planets three.js)

# alternate colorschemes to use
ALT1="palenight"
ALT2="nord"
ALT3="onedark"

if [ -z $@ ]; then
    print -l "${tasks[@]}"
else
    if [ "$@" = "abstract-algebra" ]; then
        # intro to complexity course
        i3empty.py next 1 > /dev/null
        i3-msg layout splith > /dev/null

        coproc kitty -d $NOTES/knowledge/courses/visual-group-theory nvim README.md > /dev/null
        coproc chromium https://www.youtube.com/watch?v=UwTQdOop-nU > /dev/null
    elif [ "$@" = "bayes" ]; then
        # rethinking statistics
        i3empty.py next 1 > /dev/null
        i3-msg layout splith > /dev/null

        coproc zathura ~/d/books/statisticalrethinking2.pdf > /dev/null
        coproc kitty -d $NOTES/knowledge/courses/statistical-rethinking nvim README.md > /dev/null
    elif [ "$@" = "complexity" ]; then
        # intro to complexity course
        i3empty.py next 1 > /dev/null
        i3-msg layout splith > /dev/null

        coproc kitty -d $NOTES/knowledge/courses/intro-to-complexity nvim README.md > /dev/null
        coproc chromium https://www.complexityexplorer.org/courses/119-introduction-to-complexity/segments/11742?summary > /dev/null
    elif [ "$@" = "shaders" ]; then
        # shaders practice
        i3empty.py next 1 > /dev/null
        i3-msg layout splith > /dev/null

        # copy template to a new folder
        workdir=~/d/shaders/prac/`date +"%Y-%m-%d"`
        cp -r ~/d/shaders/template $workdir

        # launch firefox / vim
        coproc kitty -d $workdir nvim shader.frag > /dev/null
        coproc firefox --new-instance -P shaders > /dev/null
    elif [ "$@" = "gene-sets" ]; then
        # gene set optimization
        i3empty.py next 1 > /dev/null
        i3-msg layout splith > /dev/null
        coproc kitty -d ~/d/r/nih/gene-sets  > /dev/null
        coproc kitty -d $NOTES/nih/gene-sets nvim gene-set-optimization.md > /dev/null
    elif [ "$@" = "dsp" ]; then
        # audio signal processing
        i3empty.py next 1 > /dev/null
        i3-msg layout splith > /dev/null
        coproc kitty -d $NOTES/courses/audio-signal-processing nvim audio-signal-processing.md > /dev/null
        coproc google-chrome-stable https://www.coursera.org/learn/audio-signal-processing/home/welcome > /dev/null
        # i3-msg '[class="^Nautilus$"] focus'
        # i3-msg splitv > /dev/null
        # i3-msg layout stacking > /dev/null
    elif [ "$@" = "coex" ]; then
        # co-expression networks 
        i3empty.py next 1 > /dev/null
        i3-msg layout splith > /dev/null
        coproc kitty -d $NOTES/tasks nvim task-coex.md > /dev/null
    elif [ "$@" = "three.js" ]; then
        i3empty.py next 1 > /dev/null
        i3-msg layout stacking > /dev/null
        coproc kitty -d ~/d/three-js > /dev/null
        coproc kitty -d $NOTES/tech/web/ nvim three-js.md > /dev/null
        coproc firefox -new-window "https://threejs.org/docs/index.html#manual/en/introduction/Creating-a-scene" > /dev/null
    elif [ "$@" = "planets" ]; then
        i3empty.py next 1 > /dev/null
        i3-msg layout stacking > /dev/null
        coproc kitty -d ~/d/three-js/00-sphere/src nvim App.js > /dev/null
        coproc kitty -d ~/d/three-js/00-sphere yarn start > /dev/null
        coproc kitty -d $NOTES/tech/procedural-generation/ nvim planets.md > /dev/null
        coproc firefox -new-window "https://threejs.org/docs/index.html#manual/en/introduction/Creating-a-scene" > /dev/null
    elif [ "$@" = "gen-art" ]; then
        i3empty.py next 1 > /dev/null
        i3-msg layout stacking > /dev/null
        coproc kitty -d ~/d/gen-art/01-hi nvim index.html > /dev/null
        coproc kitty -d ~/d/gen-art/01-hi python -m 'http.server' 8001 > /dev/null
        coproc kitty -d $NOTES/art/generative-art/ nvim generative-art.md > /dev/null
    elif [ "$@" = "l-systems" ]; then
        i3empty.py next 1 > /dev/null
        i3-msg layout stacking > /dev/null
        coproc kitty -d ~/d/l-systems/00-hello nvim index.html > /dev/null
        coproc kitty -d ~/d/l-systems/00-hello python -m 'http.server' 8001 > /dev/null
        coproc zathura ~/d/books/abop.pdf > /dev/null
        coproc kitty -d $NOTES/books nvim -c "colorscheme $ALT2" algorithmic-beauty-of-plants.md > /dev/null
        coproc kitty -d $NOTES/tech/procedural-generation/nature nvim -c "colorscheme $ALT1" l-systems.md > /dev/null
    fi
fi 
