#
# R Configuration
# KH (July 2020)
#
# For quick version upgrades:
#
#  cp -r ~/R/path/to/4.x ~/R/path/to/4.y
#  R -e "update.packages(checkBuilt = TRUE, ask = FALSE)"
#
options(browser = "firefox")
options(continue = "... ")
options(download.file.method = "libcurl")
options(dplyr.print_max = 5)
options(github.user = "khughitt")
options(keep.source.pkgs = TRUE)
options(knitr.duplicate.label = "allow")
options(max.print = 100)
options(menu.graphics = FALSE)
options(nwarnings = 1000)
options(pdfviewer = "zathura")
options(prompt = "> ")
options(rstudio.markdownToHTML = NULL)
options(setWidthOnResize = TRUE)
options(showErrorCalls = TRUE)
options(showWarnCalls = TRUE)
options(showNCalls = 100)
options(try.all.packages  = TRUE)
options(warning.length = 8170)
options(width = 100)

# options(repos = structure(c(CRAN = "https://cran.case.edu/")))

# disabled due to warnings arising from inside packages
#options(warnPartialMatchArgs = TRUE)
#options(warnPartialMatchAttr = TRUE)
#options(warnPartialMatchDollar = TRUE)

# parallelization defaults for package installation, etc.
options(mc.cores = max(1, parallel::detectCores() - 4))
options(Ncpus    = max(1, parallel::detectCores() - 4))

# this may help speed up some plots over ssh (use per-connection)
#X11.options(type = "Xlib")

# default x11 options
grDevices::X11.options(width = 4.5, height = 4, ypos = 0, xpos = 1000, pointsize = 10)

# tab complete package names and allow fuzzy case completion
utils::rc.settings(ipck = TRUE, fuzzy = TRUE)

# plotly
if (file.exists("~/.plotly/.credentials") && nzchar(system.file(package = "RJSONIO"))) {
  creds <- RJSONIO::fromJSON("~/.plotly/.credentials")
  Sys.setenv("plotly_username" = creds$username)
  Sys.setenv("plotly_api_key" = creds$api_key)
  rm(creds)
}

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
          editor = "nvim")

  # make r usable
  options(defaultPackages=c(getOption("defaultPackages"), "tidyverse"))

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

  # number of rows or columns with zero variance
  .env$z <- function(dat, axis = 1) {
    sum(apply(dat, axis, var) == 0)
  }

  # ascii density plot
  try(.env$td <- txtplot::txtdensity, silent = TRUE)

  # shortcut to load bioconductor
  try(.env$.bc <- BiocManager::install, silent = TRUE)

  # better data summarizations
  try(.env$s <- skimr::skim, silent = TRUE)

  # Prints N objects which use the most memory (in megabytes)
  .env$.top <- function(n = 10, digits = 3) {
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
  options(
      repos = c(CRAN = "http://cran.rstudio.com/"),
      browserNLdisabled = TRUE,
      deparse.max.lines = 2)

  if ((!"--no-readline" %in% commandArgs()) && interactive()) {
    utils::loadhistory(Sys.getenv("R_HISTFILE"))
  }
}

# On quit
.Last <- function() {
  # Preserve history across sessions
  if ((!"--no-readline" %in% commandArgs()) && interactive()) {
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
