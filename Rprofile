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
            vimcom.allnames=FALSE,
            vimcom.texerrs=TRUE,
            pager="vimrpager")

    # select default editor
    if(nchar(Sys.getenv("DISPLAY")) > 1)
        options(editor = 'gvim -f -c "set ft=r"')
    else
        options(editor='vim -c "set ft=r"')

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
    if(Sys.getenv("VIMRPLUGIN_TMPDIR") != "")
        library(vimcom.plus)
}

# On quit
.Last <- function() {
    # Preserve history across sessions
    if (!any(commandArgs()=='--no-readline') && interactive()){
        require(utils)
        try(savehistory(Sys.getenv("R_HISTFILE")))
    }
}

# Default HISTORY file
if (Sys.getenv("R_HISTFILE") == "") {
  Sys.setenv(R_HISTFILE=file.path("~", ".Rhistory"))
}
Sys.setenv(R_HISTSIZE=5000)

