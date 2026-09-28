# One-click installer for the `scConvert` dependency of scConvertShiny.
#
# scConvert contains C source code, so a working C toolchain (Windows: Rtools,
# Linux: build-essential, macOS: Xcode command line tools) is required.
# Run this from an R session:  source("install_scConvert.R")

options(repos = c(CRAN = "https://cloud.r-project.org"))

cat("== scConvertShiny: installing scConvert ==\n")

check_toolchain <- function() {
  has_make <- nzchar(Sys.which("make"))
  has_gcc  <- nzchar(Sys.which("gcc")) || nzchar(Sys.which("clang"))
  pkgbuild_ok <- requireNamespace("pkgbuild", quietly = TRUE) &&
    tryCatch(pkgbuild::has_build_tools(debug = FALSE), error = function(e) FALSE)
  cat("  make found : ", has_make, "\n", sep = "")
  cat("  gcc/clang  : ", has_gcc, "\n", sep = "")
  cat("  build tools: ", isTRUE(pkgbuild_ok), "\n", sep = "")
  if (!has_make) {
    stop(
      "`make` was not found on PATH. Install Rtools (Windows), ",
      "build-essential (Linux) or Xcode command line tools (macOS) first.\n",
      "See inst/install/INSTALL_PREREQUISITES.md.",
      call. = FALSE
    )
  }
  invisible(TRUE)
}

check_toolchain()

if (!requireNamespace("remotes", quietly = TRUE)) {
  cat("Installing 'remotes'...\n")
  install.packages("remotes")
}

cat("Installing scConvert from GitHub (mianaz/scConvert)...\n")
remotes::install_github("mianaz/scConvert", upgrade = "never")

if (requireNamespace("scConvert", quietly = TRUE)) {
  cat("OK: scConvert ", as.character(utils::packageVersion("scConvert")),
      " installed.\n", sep = "")
} else {
  stop("scConvert installation did not succeed.", call. = FALSE)
}
