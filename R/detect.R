# Input format detection.
#
# Mirrors scConvert's internal FileType() logic so the app can classify an
# input before scConvert is loaded, and refines .h5ad into its spatial variant
# when hdf5r is available.

#' Detect the format of an input path or URI
#'
#' @param path A file path, directory path or URI (e.g. `soma://...`).
#' @param check_exists Unused placeholder kept for API stability; existence is
#'   reported in the returned `exists` field.
#' @return A list with `path`, `id`, `label`, `kind`, `can_read`, `recognized`
#'   and `exists`, or `NULL` for an empty path.
#' @export
sc_detect_input <- function(path, check_exists = TRUE) {
  if (is.null(path) || !nzchar(path)) return(NULL)

  uri_scheme <- NA_character_
  if (grepl("^[a-zA-Z][a-zA-Z0-9+.-]*://", path)) {
    uri_scheme <- tolower(sub("://.*", "", path))
  }
  bn <- basename(path)

  id <- NA_character_
  if (!is.na(uri_scheme)) {
    id <- uri_scheme
  } else if (grepl("\\.spatialdata\\.zarr$", bn, ignore.case = TRUE)) {
    id <- "spatialdata.zarr"
  } else if (grepl("\\.cellbin\\.gef$", bn, ignore.case = TRUE)) {
    id <- "cellbin.gef"
  } else if (grepl("\\.gef$", bn, ignore.case = TRUE)) {
    id <- "gef"
  } else if (dir.exists(path) && sc_is_cosmx_dir(path)) {
    id <- "cosmx"
  } else {
    ext <- tolower(tools::file_ext(bn))
    if (!nzchar(ext)) ext <- tolower(bn)
    id <- switch(
      ext,
      "h5ad" = "h5ad",
      "h5seurat" = "h5seurat",
      "h5mu" = "h5mu",
      "loom" = "loom",
      "rds" = "rds",
      "zarr" = "zarr",
      "gef" = "gef",
      "cellbin.gef" = "cellbin.gef",
      "spatialdata.zarr" = "spatialdata.zarr",
      "soma" = "soma",
      NA_character_
    )
  }

  # Refine plain h5ad into the spatial variant when the file exposes spatial keys.
  if (identical(id, "h5ad") &&
      requireNamespace("hdf5r", quietly = TRUE) &&
      file.exists(path) &&
      isTRUE(sc_h5ad_is_spatial(path))) {
    id <- "h5ad_spatial"
  }

  sc_detection(path, id)
}

#' Build a detection result for a format id
#' @noRd
sc_detection <- function(path, id) {
  row <- sc_format_by_id(id)
  exists_flag <- if (!is.character(path) || length(path) != 1 || is.na(path)) {
    NA
  } else if (grepl("://", path)) {
    NA
  } else {
    file.exists(path) || dir.exists(path)
  }
  list(
    path = path,
    id = id,
    label = if (nrow(row)) row$label[1] else "Unknown format",
    kind = if (nrow(row)) row$kind[1] else NA_character_,
    can_read = if (nrow(row)) isTRUE(row$can_read[1]) else FALSE,
    recognized = nrow(row) == 1 && !is.na(id),
    exists = exists_flag
  )
}

#' Detect the format inside a .zip archive without extracting it
#'
#' Reads only the archive index (fast) and infers the format from member
#' names, so directory-based formats (Zarr, SpatialData, CosMx) can be
#' recognised from a zipped folder before extraction.
#'
#' @param zip_path Path to the .zip file.
#' @return A detection list (see [sc_detect_input()]).
#' @export
sc_detect_zip <- function(zip_path) {
  ent <- tryCatch(
    utils::unzip(zip_path, list = TRUE)$Name,
    error = function(e) character(0), warning = function(w) character(0)
  )
  ent <- ent[!is.na(ent)]
  if (!length(ent)) return(sc_detection(zip_path, NA_character_))
  files <- ent[!grepl("/$", ent)]
  bn <- basename(ent)

  if (any(grepl("\\.spatialdata\\.zarr/", ent, ignore.case = TRUE))) {
    return(sc_detection(zip_path, "spatialdata.zarr"))
  }
  if (any(grepl("\\.zarr/", ent, ignore.case = TRUE))) {
    return(sc_detection(zip_path, "zarr"))
  }
  if (any(grepl("\\.cellbin\\.gef$", bn, ignore.case = TRUE))) {
    return(sc_detection(zip_path, "cellbin.gef"))
  }
  if (any(grepl("\\.gef$", bn, ignore.case = TRUE))) {
    return(sc_detection(zip_path, "gef"))
  }
  if (length(files) == 1) {
    d <- sc_detect_input(basename(files))
    return(sc_detection(zip_path, d$id))
  }
  if (sum(grepl("\\.csv$", bn, ignore.case = TRUE)) >= 3) {
    return(sc_detection(zip_path, "cosmx"))
  }
  sc_detection(zip_path, NA_character_)
}

#' Heuristic: is a directory a NanoString CosMx bundle?
#' @noRd
sc_is_cosmx_dir <- function(path) {
  if (!dir.exists(path)) return(FALSE)
  files <- tryCatch(list.files(path), error = function(e) character(0))
  any(grepl("_tx_file\\.csv$", files, ignore.case = TRUE)) ||
    any(grepl("expr_mat", files, ignore.case = TRUE))
}

#' Heuristic: does an h5ad file contain spatial information?
#' @noRd
sc_h5ad_is_spatial <- function(path) {
  tryCatch({
    h5 <- hdf5r::H5File$new(path, mode = "r")
    on.exit(h5$close_all(), add = TRUE)
    isTRUE(h5$exists("obsm/spatial")) || isTRUE(h5$exists("uns/spatial"))
  }, error = function(e) FALSE)
}

# Default assay name per format, used when it cannot be read from the file and
# as the preferred selection when several are present.
.sc_assay_defaults <- c(
  h5ad = "RNA", h5ad_spatial = "RNA", h5seurat = "RNA", h5mu = "RNA",
  loom = "RNA", rds = "RNA", zarr = "RNA", soma = "RNA",
  spatialdata.zarr = "RNA", sce = "RNA",
  gef = "Spatial", cellbin.gef = "Spatial", cosmx = "Nanostring"
)

#' Detect assay names available in an input
#'
#' Only cheap, non-destructive probes are used: h5Seurat assay groups
#' (`/assays`) and MuData modalities (`/mod`) are listed straight from the
#' HDF5 file; other formats fall back to a sensible default (`"RNA"`, or
#' `"Spatial"` / `"Nanostring"` for Stereo-seq GEF / CosMx). RDS contents are
#' not read here to avoid loading large objects on every keystroke.
#'
#' @param path Local path to the input, or `NA`/`NULL` when not yet available.
#' @param source_id Format id from [sc_detect_input()].
#' @param caps Optional result of [sc_capabilities()].
#' @return A list with `assays` (detected names, possibly empty),
#'   `default` (name to preselect) and `source` (`"detected"` or `"format"`).
#' @export
sc_detect_assays <- function(path, source_id, caps = sc_capabilities()) {
  fallback <- unname(.sc_assay_defaults[source_id])
  if (length(fallback) != 1 || is.na(fallback)) fallback <- "RNA"

  assays <- character(0)
  readable <- !is.null(path) && length(path) == 1 &&
    !is.na(path) && nzchar(path) && !grepl("://", path) &&
    file.exists(path) && requireNamespace("hdf5r", quietly = TRUE)

  if (readable) {
    if (identical(source_id, "h5seurat")) {
      assays <- sc_h5_children(path, "assays")
    } else if (identical(source_id, "h5mu")) {
      assays <- sc_h5_children(path, "mod")
      assays <- sub("^rna$", "RNA", assays, ignore.case = TRUE)
      assays <- sub("^prot$", "ADT", assays, ignore.case = TRUE)
    }
  }
  assays <- unique(assays[nzchar(assays)])
  default <- if (fallback %in% assays) fallback else if (length(assays)) assays[1] else fallback
  list(
    assays = assays,
    default = default,
    source = if (length(assays)) "detected" else "format"
  )
}

#' Names of the children of an HDF5 group (empty if absent/unreadable)
#' @noRd
sc_h5_children <- function(path, group) {
  tryCatch({
    h5 <- hdf5r::H5File$new(path, mode = "r")
    on.exit(h5$close_all(), add = TRUE)
    if (!isTRUE(h5$exists(group))) return(character(0))
    g <- h5[[group]]
    if (!inherits(g, "H5Group")) return(character(0))
    names(g)
  }, error = function(e) character(0))
}
