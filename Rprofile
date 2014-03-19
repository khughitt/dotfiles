#
# R Configuration
#
options(showWarnCalls=T, showErrorCalls=T)
options(max.print=10E3)
options(repos=structure(c(CRAN="http://watson.nci.nih.gov/cran_mirror/")))
options(menu.graphics=F)
options(github.user="khughitt")

# interactive mode
if (interactive()) {
    # console settings
    options(setwidth.verbose=1,
            colorout.verbose=1,
            vimcom.verbose=1,
            pager="/home/keith/bin/vimrpager")
    # Use the text based web browser w3m to navigate through R docs:
    #if(Sys.getenv("TMUX") != "")
    #    options(browser="~/bin/vimrw3mbrowser", help_type = "html")

    # select default editor
    if(nchar(Sys.getenv("DISPLAY")) > 1)
        options(editor = 'gvim')
    else
        options(editor='vim')

    # syntax highlighting
    library(colorout)
    if (!Sys.getenv('TERM')  %in% c('', 'linux'))
        setOutputColors256(
            normal = 15,
            number = 12,
            negnum = 9,
            string = 10,
            const  = 13,
            stderror = 120,
            error = c(1, 0, 1),
            warn = 5,
            verbose=FALSE
        )

    # updates output width when terminal is resized
    library(setwidth)

    # better vim support
    if(Sys.getenv("VIMRPLUGIN_TMPDIR") != "") {
        library(vimcom.plus)
        # See R docs Vim buffer even if asking for help in R Console:
        if(Sys.getenv("VIM_PANE") != "")
            options(help_type = "text", pager = vim.pager)
    }
}

# On quit
.Last <- function() {
    # Preserve history across sessions
    if (!any(commandArgs()=='--no-readline') && interactive()){
        require(utils)
        try(savehistory(Sys.getenv("R_HISTFILE")))
    }
}

# Shortcut to load bioconductor
bc = function() {
    print('Sourcing http://bioconductor.org/biocLite.R')
    source("http://bioconductor.org/biocLite.R")
}

# Default HISTORY file
if (Sys.getenv("R_HISTFILE") == "") {
  Sys.setenv(R_HISTFILE=file.path("~", ".Rhistory"))
}
Sys.setenv(R_HISTSIZE=5000)

