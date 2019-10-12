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
options(dplyr.print_max = 5) 
options(github.user = "khughitt")
options(help.search.types = c("name", "title", "alias", "concept", "keyword"))
options(keep.source.pkgs = TRUE)
options(knitr.duplicate.label = 'allow')
options(max.print = 100)
options(menu.graphics = F)
options(nwarnings = 1000)
options(pdfviewer = 'zathura')
options(prompt = "> ")
options(repos = structure(c(CRAN = "http://lib.stat.cmu.edu/R/CRAN/")))
options(rstudio.markdownToHTML = NULL)
options(setWidthOnResize = TRUE)
options(showErrorCalls = TRUE)
options(showWarnCalls = TRUE)
options(showNCalls = 100)
options(try.all.packages  = TRUE)
options(warning.length = 8170)
options(warnPartialMatchAttr = TRUE)
options(warnPartialMatchDollar = TRUE)
options(warning.length = 5000)
options(width = 100)

# disabled due to warnings arising from inside packages
#options(warnPartialMatchArgs = TRUE)

# parallelization defaults for package installation, etc.
options(mc.cores = min(1, parallel::detectCores() - 4))
options(Ncpus    = min(1, parallel::detectCores() - 4))

# this may help speed up some plots over ssh (use per-connection)
#X11.options(type = 'Xlib')

# default x11 options
grDevices::X11.options(width = 4.5, height = 4, ypos = 0, xpos = 1000, pointsize = 10)

# tab complete package names and allow fuzzy case completion
utils::rc.settings(ipck = TRUE, fuzzy = TRUE)

#
# radian
#
options(radian.auto_match = TRUE)
options(radian.tab_size = 2)
options(radian.history_search_no_duplicates = FALSE)

# breaks cntl-left / cntl-right / etc. 
#options(radian.editing_mode = "vi")

# custom prompt for different modes
#options(radian.prompt = "\033[0;34mr$>\033[0m ")
#options(radian.shell_prompt = "\033[0;31m#!>\033[0m ")
#options(radian.browse_prompt = "\033[0;33mBrowse[{}]>\033[0m ")

# interactive mode
if (interactive()) {
  # console settings
  options(colorout.verbose = 1,
          vimcom.verbose = 1,
          editor = 'nvim')

  # syntax highlighting
  if (isatty(stdout())) {
    try({
      library(colorout)
      # setOutputColors(
      #   normal   = "\x1b[38;2;9;179;153m", #"\x1b[38;2;247;149;50m",
      #   negnum   = "\x1b[38;2;239;78;124m",
      #   zero     = "\x1b[38;2;160;103;171m",
      #   number   = "\x1b[38;2;18;153;173m",
      #   date     = "\x1b[38;2;247;149;50m",
      #   string   = "\x1b[38;2;110;187;130m",
      #   const    = "\x1b[38;2;247;149;50m",
      #   false    = "\x1b[38;2;239;78;124m",
      #   true     = "\x1b[38;2;18;153;173m",
      #   infinite = "\x1b[38;2;247;149;50m",
      #   index    = "\x1b[38;2;18;153;173m",
      #   stderror = "\x1b[38;2;239;78;124m",
      #   warn     = "\x1b[38;2;243;112;85m",
      #   error    = "\x1b[38;2;222;223;223;48;2;239;78;124m",
      #   zero.limit = 0.001, verbose = FALSE)
      setOutputColors(
        normal   = "\x1b[32m",
        negnum   = "\x1b[31m",
        zero     = "\x1b[95m",
        number   = "\x1b[34m",
        date     = "\x1b[33m",
        string   = "\x1b[34m",
        const    = "\x1b[92;1m",
        false    = "\x1b[31m",
        true     = "\x1b[34m",
        infinite = "\x1b[94;1m",
        index    = "\x1b[36m",
        stderror = "\x1b[95m",
        warn     = "\x1b[35;1m",
        error    = "\x1b[31;1m",
        zero.limit = 0.001, verbose = FALSE)
    }, silent = TRUE)
  }
  #
  # Helper functions
  #
  # Defined in a separate hidden environment
  # (https://csgillespie.github.io/efficientR/3-3-r-startup.html)
  #
  .env <- new.env()

  # show first three/six columns and rows of a matrix / dataframe
  .env$h  <- function(dat) {
    dat[1:min(3, nrow(dat)), 1:min(3, ncol(dat))]
  }
  .env$hh <- function(dat) {
    dat[1:min(6, nrow(dat)), 1:min(6, ncol(dat))]
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

  # Prints N objects which use the most memory (in megabytes)
  .env$.top = function(n = 10, digits = 3) {
    vars <- ls(.GlobalEnv)

    if (length(vars) > 0) {
      print(round(tail(sort(sapply(vars, function(x){ object.size(get(x)) })), n) / 1E6), digits)
    } else {
      print("No variables currently defined in global environment.")
    }
  }
  attach(.env)
}

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
