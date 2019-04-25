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
options(dplyr.print_max = 20) 
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

# this may help speed up some plots over ssh (use per-connection)
#X11.options(type = 'Xlib')

# tab complete package names and allow fuzzy case completion
utils::rc.settings(ipck = TRUE, fuzzy = TRUE)

# radian
options(radian.editing_mode = "vi")
options(radian.auto_match = TRUE)
options(radian.tab_size = 2)

# custom prompt for different modes
#options(radian.prompt = "\033[0;34mr$>\033[0m ")
#options(radian.shell_prompt = "\033[0;31m#!>\033[0m ")
#options(radian.browse_prompt = "\033[0;33mBrowse[{}]>\033[0m ")

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
        try(library(colorout), silent = TRUE)
    }
}

#
# Helper functions
#
# Defined in a separate hidden environment
# (https://csgillespie.github.io/efficientR/3-3-r-startup.html)
#
.env <- new.env()

# show first three columns and rows of a matrix / dataframe
.env$h  <- function(dat) {
  dat[1:min(3, nrow(dat)), 1:min(3, ncol(dat))]
}

# number of nas by column or row
.env$nna <- function(dat, axis = 1, num_non_na = FALSE) {
  if (num_non_na) {
    apply(dat, axis, function (x) { sum(!is.na(x)) })
  } else {
    apply(dat, axis, function (x) { sum(is.na(x)) })
  }
}

# ascii density plot
try(.env$td <- txtplot::txtdensity, silent = TRUE)

# Shortcut to load bioconductor
try(.env$.bc <- BiocManager::install, silent = TRUE)

# Memory usage
.env$.top = function(n = 10) {
    # Prints N objects which use the most memory (in megabytes)
    print(tail(sort(sapply(ls(),function(x){ object.size(get(x)) })), n) / 1E6)
}
attach(.env)

# On startup
.First <- function () {
  if ((!'--no-readline' %in% commandArgs()) && interactive()) {
    utils::loadhistory(Sys.getenv('R_HISTFILE')) 
  }
}

# On quit
.Last <- function() {
#  # Preserve history across sessions
  if ((!'--no-readline' %in% commandArgs()) && interactive()) {
    # Append to history instead of over-writing it
    # Adapted from https://stackoverflow.com/a/13525172/554531
    try({
      # store old history in a temporary file
      full_hist <- tempfile()
      file.copy(Sys.getenv("R_HISTFILE"), full_hist)

      # save the history for the current session
      utils::savehistory(Sys.getenv("R_HISTFILE"))

      # append the current session history to the temp file and copy it back over
      file.append(full_hist, Sys.getenv("R_HISTFILE"))
      file.copy(full_hist, Sys.getenv("R_HISTFILE"), overwrite = TRUE)

      # TODO: add check to limit the history size...
    })
  }
}
