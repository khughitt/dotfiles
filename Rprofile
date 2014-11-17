#
# R Configuration
#
options(showWarnCalls=T, showErrorCalls=T)
options(warning.length=8170)
options(max.print=300)
options(repos=structure(c(CRAN="http://watson.nci.nih.gov/cran_mirror/")))
options(menu.graphics=F)
options(github.user="khughitt")

options(prompt="> ")
options(continue="... ")

q <- function (save="no", ...) {
  quit(save=save, ...)
}

# tab complete package names
utils::rc.settings(ipck=TRUE)

options('rstudio.markdownToHTML'=NULL)

## For knitr bootstrap
## More info at http://www.rstudio.com/ide/docs/authoring/markdown_custom_rendering
#options(rstudio.markdownToHTML =
#  function(inputFile, outputFile) {
#    library(knitrBootstrap)
#    library(rmarkdown)
#    render(inputFile, knitrBootstrap::bootstrap_document(),
#           output_file=outputFile)
#  }
#)

# interactive mode
if (interactive()) {
    # console settings
    options(setwidth.verbose=0,
            colorout.verbose=1,
            vimcom.verbose=1)
            #pager=file.path(Sys.getenv("HOME"), "bin/vimrpager"))

    # Use the text based web browser w3m to navigate through R docs:
    #if(Sys.getenv("TMUX") != "")
    #    options(browser="~/bin/vimrw3mbrowser", help_type = "html")

    # select default editor
    #if(nchar(Sys.getenv("DISPLAY")) > 1)
        #options(editor = 'gvim')
    #    options(editor = 'gvim -f -c "set ft=r"')
    #else
    #    options(editor='vim')
    options(editor='vim')

    # If R started by vim
    if(Sys.getenv("VIMRPLUGIN_TMPDIR") != "") {
        # better vim support on server
        if(substring(Sys.getenv("HOME"), 0, 5) == "/cbcb") {
            .libPaths("/cbcb/lab/nelsayed/local/R")
        }
        library(vimcom)
        # See R docs Vim buffer even if asking for help in R Console:
        #if(Sys.getenv("VIM_PANE") != "")
        #    options(help_type = "text", pager=vim.pager)
    }

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

}

# Default HISTORY file
if (Sys.getenv("R_HISTFILE") == "") {
  Sys.setenv(R_HISTFILE=file.path("~", ".Rhistory"))
}
Sys.setenv(R_HISTSIZE=5000)

#.First <- function(){
#  if(interactive()){
#    library(utils)
#    timestamp(,prefix=paste0("##------ [", system('hostname', intern=TRUE),"] "))
 
#  }
#}

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

