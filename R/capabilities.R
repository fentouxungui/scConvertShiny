# Capability detection for scConvertShiny.
#
# The app must start and remain useful even when the heavy dependencies
# (scConvert / Seurat / SingleCellExperiment) are not installed, so every
# optional dependency is probed at runtime instead of being hard-required.

#' Detect available conversion capabilities
#'
#' @return A list describing which optional packages are available and which
#'   conversion backend is active.
#' @export
sc_capabilities <- function() {
  has <- function(p) requireNamespace(p, quietly = TRUE)
  sc <- has("scConvert")
  sc_version <- if (sc) {
    tryCatch(
      as.character(utils::packageVersion("scConvert")),
      error = function(e) NA_character_
    )
  } else {
    NA_character_
  }
  list(
    scConvert = sc,
    scConvertVersion = sc_version,
    Seurat = has("Seurat"),
    SeuratObject = has("SeuratObject"),
    SingleCellExperiment = has("SingleCellExperiment"),
    BPCells = has("BPCells"),
    hdf5r = has("hdf5r"),
    tiledbsoma = has("tiledbsoma"),
    backend = getOption("scConvertShiny.backend", "scConvert")
  )
}

#' Is a conversion backend ready to run?
#'
#' The "stub" backend is available without scConvert and is intended for
#' testing the application flow; the default "scConvert" backend requires the
#' scConvert package.
#'
#' @param caps Optional result of [sc_capabilities()].
#' @return A single logical.
#' @export
sc_backend_ready <- function(caps = sc_capabilities()) {
  isTRUE(caps$scConvert) || identical(caps$backend, "stub")
}
