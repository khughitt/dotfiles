options(showWarnCalls=T, showErrorCalls=T)
options(repos=structure(c(CRAN="http://watson.nci.nih.gov/cran_mirror/")))

# Syntax highlighting
library('colorout')
setOutputColors256(
    normal = 100,
    number = 98,
    negnum = 215,
    string = 85,
    const = 35,
    stderror = 203,
    error = c(1, 0, 1), 
    warn = c(1, 0, 100)
)

#setOutputColors256(
#    normal = 40,
#    number = 214,
#    string = 85,
#    const = 35,
#    stderror = 45,
#    error = c(1, 0, 1), 
#    warn = c(1, 0, 100)
#)

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

# Use last(x) instead of x[length(x)], works on matrices too
last <- function(x) { tail(x, n = 1) }

# Default HISTORY file
if (Sys.getenv("R_HISTFILE") == "") {
  Sys.setenv(R_HISTFILE=file.path("~", ".Rhistory"))
}

