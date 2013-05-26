#
# R Configuration
#
options(showWarnCalls=T, showErrorCalls=T)
options(max.print=10E3)
options(repos=structure(c(CRAN="http://watson.nci.nih.gov/cran_mirror/")))

# interactive mode
if (interactive() && Sys.getenv('TERM') != '') {
    library(setwidth)     # updates output width when terminal is resized
    library(vimcom)       # better vim suport

    library('colorout')   # syntax highlighting
    setOutputColors256(
        normal = 40,
        number = 177,
        negnum = 211, #212,
        string = 85,
        const = 35,
        stderror = 203,
        error = c(1, 0, 1), 
        warn = c(1, 0, 100)
    )
}

# On quit
.Last <- function() {
    # Preserve history across sessions
    if (!any(commandArgs()=='--no-readline') && interactive()){
        require(utils)
        try(savehistory(Sys.getenv("R_HISTFILE")))
    }
}

# Aliases
cd <- setwd
pwd <- getwd

# Default HISTORY file
if (Sys.getenv("R_HISTFILE") == "") {
  Sys.setenv(R_HISTFILE=file.path("~", ".Rhistory"))
}

