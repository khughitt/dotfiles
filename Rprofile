options(showWarnCalls=T, showErrorCalls=T)
options(repos=structure(c(CRAN="http://watson.nci.nih.gov/cran_mirror/")))

# Syntax highlighting
library('colorout')
setOutputColors256(
    normal = 40,
    number = 214,
    string = 85,
    const = 35,
    stderror = 45,
    error = c(1, 0, 1), 
    warn = c(1, 0, 100)
)

.Last <- function() {
    # Preserve history across sessions
    if (!any(commandArgs()=='--no-readline') && interactive()){
        require(utils)
        try(savehistory(Sys.getenv("R_HISTFILE")))
    }
}

