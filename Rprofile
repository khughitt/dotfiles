options(showWarnCalls=T, showErrorCalls=T)
options(repos=structure(c(CRAN="http://watson.nci.nih.gov/cran_mirror/")))

# TEMP WORK-AROUND 2012/11/08
# http://stackoverflow.com/questions/13235100/empty-plot-in-r
setHook(packageEvent("grDevices", "onLoad"),
        function(...) grDevices::X11.options(width=8, height=8, 
                                             xpos=0, pointsize=10, 
                                             type="nbcairo"))
# Syntax highlighting
library('colorout')
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

# Default HISTORY file
if (Sys.getenv("R_HISTFILE") == "") {
  Sys.setenv(R_HISTFILE=file.path("~", ".Rhistory"))
}

