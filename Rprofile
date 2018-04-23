#
# R Configuration
#
options(download.file.method = "libcurl")
options(dplyr.print_max=30) 
options(github.user="khughitt")
options(knitr.duplicate.label='allow')
options(max.print=100)
options(menu.graphics=F)
options(repos=structure(c(CRAN="http://lib.stat.cmu.edu/R/CRAN/")))
options(showWarnCalls=T, showErrorCalls=T)
options(warning.length=8170)

options(prompt="> ")
options(continue="... ")

# tab complete package names
utils::rc.settings(ipck=TRUE)

options('rstudio.markdownToHTML'=NULL)

# interactive mode
if (interactive()) {
    # console settings
    options(colorout.verbose=1,
            vimcom.verbose=1)

    options(editor='vim')

    # If R started by vim
    if(Sys.getenv("VIMRPLUGIN_TMPDIR") != "") {
        library(vimcom)
    }

    # syntax highlighting
    if (isatty(stdout())) {
        library(colorout)
    }
}

# Default HISTORY file
if (Sys.getenv("R_HISTFILE") == "") {
  Sys.setenv(R_HISTFILE=file.path("~", ".Rhistory"))
}
Sys.setenv(R_HISTSIZE=5000)

# On quit
.Last <- function() {
    # Preserve history across sessions
    if (!any(commandArgs()=='--no-readline') && interactive()){
        require(utils)
        try(savehistory(Sys.getenv("R_HISTFILE")))
    }
}

# Shortcut to load bioconductor
.bc = function() {
    print('Sourcing http://bioconductor.org/biocLite.R')
    source("http://bioconductor.org/biocLite.R")
}

# Memory usage
.top = function(n=10) {
    # Prints N objects which use the most memory (in megabytes)
    print(tail(sort(sapply(ls(),function(x){object.size(get(x))})), n)/1E6)
}
