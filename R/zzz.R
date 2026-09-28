# Internal utilities and package metadata

# Null-coalescing operator (base R only added `%||%` in 4.4; support R >= 4.1).
`%||%` <- function(x, y) if (is.null(x)) y else x

# Package-level doc placeholder so `?_PACKAGE` resolves.
"_PACKAGE"

#' @noRd
sc_scalar_chr <- function(x, default = NA_character_) {
  if (is.null(x) || length(x) == 0 || is.na(x[1])) default else as.character(x[1])
}

#' @noRd
sc_now <- function() format(Sys.time(), "%Y-%m-%d %H:%M:%S")

.onLoad <- function(libname, pkgname) {
  if (is.null(getOption("scConvertShiny.maxUploadMB"))) {
    options(scConvertShiny.maxUploadMB = 20 * 1024)
  }
  invisible(NULL)
}
