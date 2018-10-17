#
# R Configuration
#
# For quick version updates:
#
#  cp -r ~/R/path/to/3.x ~/R/path/to/3.y
#  R -e "update.packages(checkBuilt = TRUE, ask = FALSE)"
#
options(continue = "... ")
options(download.file.method = "libcurl")
options(dplyr.print_max = 30) 
options(github.user = "khughitt")
options(knitr.duplicate.label = 'allow')
options(max.print = 100)
options(menu.graphics = F)
options(prompt = "> ")
options(repos = structure(c(CRAN = "http://lib.stat.cmu.edu/R/CRAN/")))
options(rstudio.markdownToHTML = NULL)
options(showWarnCalls = T, showErrorCalls = T)
options(warning.length = 8170)
options(width = 100)

# tab complete package names and allow fuzzy case completion
utils::rc.settings(ipck = TRUE, fuzzy = TRUE)

# rtichoke
options(
    # see https://help.farbox.com/pygments.html
    # for a list of supported color schemes, default scheme is "native"
    rtichoke.color_scheme = "native",

    # either  `"emacs"` (default) or `"vi"`.
    rtichoke.editing_mode = "vi",

    # indent continuation lines
    # turn this off if you want to copy code without the extra indentation;
    # but it leads to less elegent layout
    rtichoke.indent_lines = TRUE,

    # auto match brackets and quotes
    rtichoke.auto_match = FALSE,

    # auto indentation for new line and curly braces
    rtichoke.auto_indentation = TRUE,
    rtichoke.tab_size = 4,

    # pop up completion while typing
    rtichoke.complete_while_typing = TRUE,

    # timeout in seconds to cancel completion if it takes too long
    # set it to 0 to disable it
    rtichoke.completion_timeout = 0.05,

    # automatically adjust R buffer size based on terminal width
    rtichoke.auto_width = TRUE,

    # insert new line between prompts
    rtichoke.insert_new_line = TRUE,

    # when using history search (ctrl-r/ctrl-s in emacs mode), do not show duplicate results
    rtichoke.history_search_no_duplicates = FALSE,

    # custom prompt for different modes
    rtichoke.prompt = "\033[0;34m>\033[0m ",
    rtichoke.shell_prompt = "\033[0;31m#!>\033[0m ",
    rtichoke.browse_prompt = "\033[0;33mBrowse[{}]>\033[0m ",

    # supress the loading message for reticulate
    rtichoke.suppress_reticulate_message = FALSE,
    # enable reticulate prompt and trigger `~`
    rtichoke.enable_reticulate_prompt = TRUE
)

# interactive mode
if (interactive()) {
    # console settings
    options(colorout.verbose = 1,
            vimcom.verbose = 1)

    options(editor = 'vim')

    # If R started by vim
    if(Sys.getenv("VIMRPLUGIN_TMPDIR") !=  "") {
        library(vimcom)
    }

    # syntax highlighting
    if (isatty(stdout())) {
        library(colorout)
    }
}

# Helper functions
# https://csgillespie.github.io/efficientR/3-3-r-startup.html
.env <- new.env()
.env$hh <- function(d) d[1:min(3, nrow(d)), 1:min(3, ncol(d))]
attach(.env)

# Default HISTORY file
if (Sys.getenv("R_HISTFILE") == "") {
  Sys.setenv(R_HISTFILE = file.path("~", ".Rhistory"))
}
Sys.setenv(R_HISTSIZE = 5000)

# On quit
.Last <- function() {
    # Preserve history across sessions
    if (!any(commandArgs()=='--no-readline') && interactive()){
        require(utils)
        try(savehistory(Sys.getenv("R_HISTFILE")))
    }
}

# Shortcut to load bioconductor
.bc <- BiocManager::install

# Memory usage
.top = function(n = 10) {
    # Prints N objects which use the most memory (in megabytes)
    print(tail(sort(sapply(ls(),function(x){ object.size(get(x)) })), n) / 1E6)
}
