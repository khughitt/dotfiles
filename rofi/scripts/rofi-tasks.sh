#!/bin/zsh
#
# rofi tasks launcher
# kh (jan 2021)
#
tasks=(bayes dsp gene-sets shaders)

if [ -z $@ ]; then
    print -l "${tasks[@]}"
else
    if [ "$@" = "bayes" ]; then
        # rethinking statistics
        i3empty.py next 1 > /dev/null
        i3-msg layout splith > /dev/null

        coproc zathura ~/d/books/statisticalrethinking2.pdf > /dev/null
        coproc termite -d $NOTES/knowledge/courses/statistical-rethinking -e "nvim stat-rethink.md" > /dev/null
    elif [ "$@" = "shaders" ]; then
        # shaders practice
        i3empty.py next 1 > /dev/null
        i3-msg layout splith > /dev/null

        # copy template to a new folder
        workdir=~/d/shaders/prac/`date +"%Y-%m-%d"`
        cp -r ~/d/shaders/template $workdir

        # launch firefox / vim
        coproc termite -d $workdir -e "nvim shader.frag" > /dev/null
        coproc firefox --new-instance -P shaders > /dev/null
    elif [ "$@" = "gene-sets" ]; then
        # gene set optimization
        i3empty.py next 1 > /dev/null
        i3-msg layout splith > /dev/null
        coproc termite -d ~/d/r/nih/gene-sets  > /dev/null
        coproc termite -d $NOTES/nih/gene-sets -e "nvim gene-set-optimization.md" > /dev/null
    elif [ "$@" = "dsp" ]; then
        # audio signal processing
        i3empty.py next 1 > /dev/null
        i3-msg layout splith > /dev/null

        coproc termite -d $NOTES/courses/audio-signal-processing -e "nvim audio-signal-processing.md" > /dev/null
        coproc google-chrome-stable https://www.coursera.org/learn/audio-signal-processing/home/welcome > /dev/null
        # i3-msg '[class="^Nautilus$"] focus'
        # i3-msg splitv > /dev/null
        # i3-msg layout stacking > /dev/null
    elif [ "$@" = "coex" ]; then
        # co-expression networks 
        i3empty.py next 1 > /dev/null
        i3-msg layout splith > /dev/null

        coproc termite -d $NOTES/tasks -e "nvim task-coex.md" > /dev/null
    fi
fi 
