# Format capability matrix for scConvertShiny.
#
# The matrix is derived from scConvert's `.onLoad()` registrations
# (R/zzz.R) and its public read*/write* helpers, so the app never offers an
# illegal source -> target combination.

#' Single-cell formats supported by scConvert
#'
#' @return A data.frame with one row per format and the columns `id`, `label`,
#'   `ext`, `kind` (file/dir/uri/memory), `ecosystem`, `can_read`, `can_write`,
#'   `canonical` and `notes`.
#' @export
sc_formats <- function() {
  data.frame(
    id = c(
      "h5ad", "h5ad_spatial", "h5seurat", "h5mu", "loom", "rds",
      "zarr", "soma", "spatialdata.zarr", "sce", "gef", "cellbin.gef",
      "cosmx"
    ),
    label = c(
      "AnnData (.h5ad)",
      "Spatial AnnData (.h5ad)",
      "h5Seurat (.h5Seurat)",
      "MuData (.h5mu)",
      "Loom (.loom)",
      "RDS (.rds)",
      "Zarr directory (.zarr)",
      "TileDB-SOMA (soma://)",
      "SpatialData (.spatialdata.zarr)",
      "SingleCellExperiment (in-memory)",
      "Stereo-seq GEF (.gef)",
      "Stereo-seq cellbin GEF (.cellbin.gef)",
      "NanoString CosMx (directory)"
    ),
    ext = c(
      ".h5ad", ".h5ad", ".h5Seurat", ".h5mu", ".loom", ".rds", ".zarr",
      ".soma", ".spatialdata.zarr", ".sce.rds", ".gef", ".cellbin.gef", ""
    ),
    kind = c(
      "file", "file", "file", "file", "file", "file",
      "dir", "uri", "dir", "memory", "file", "file", "dir"
    ),
    ecosystem = c(
      "scanpy / CELLxGENE", "Visium / squidpy", "Seurat", "muon / multimodal",
      "loompy / HCA", "R native", "cloud AnnData", "CELLxGENE Census",
      "scverse spatial", "Bioconductor", "STOmics", "STOmics", "NanoString"
    ),
    can_read = c(
      TRUE, TRUE, TRUE, TRUE, TRUE, TRUE,
      TRUE, TRUE, TRUE, FALSE, TRUE, TRUE, TRUE
    ),
    can_write = c(
      TRUE, TRUE, TRUE, TRUE, TRUE, TRUE,
      TRUE, TRUE, TRUE, TRUE, FALSE, FALSE, FALSE
    ),
    canonical = c(
      TRUE, TRUE, TRUE, TRUE, TRUE, TRUE,
      TRUE, TRUE, TRUE, TRUE, TRUE, TRUE, FALSE
    ),
    notes = c(
      "Seurat hub; a direct HDF5 path speeds up h5ad<->h5Seurat",
      "h5ad variant; rebuilds images and scale factors when /uns/spatial or /obsm/spatial is present",
      "Native Seurat format",
      "Multimodal CITE-seq / ATAC+RNA",
      "Converted through the Seurat hub",
      "Stores a Seurat object (read with readRDS)",
      "Directory format; scConvert streams via a temporary h5seurat",
      "Local or remote TileDB-SOMA URI",
      "Directory format; contains OME-NGFF images",
      "In-memory target only; this app saves it as <name>.sce.rds for download",
      "Square-bin Stereo-seq, read-only",
      "cellbin GEF, read-only",
      "Additional scConvert support, read-only"
    ),
    stringsAsFactors = FALSE
  )
}

#' Look up one format by id
#' @noRd
sc_format_by_id <- function(id) {
  f <- sc_formats()
  f[match(id, f$id), , drop = FALSE]
}

#' Ids that can be used as conversion targets
#'
#' `h5ad_spatial` is excluded because writing a spatial h5ad happens
#' automatically whenever the Seurat object carries images. `sce` is offered
#' only when SingleCellExperiment is installed, and `soma` only when the
#' tiledbsoma package is available.
#'
#' @export
sc_valid_targets <- function(caps = sc_capabilities()) {
  f <- sc_formats()
  ids <- f$id[f$can_write & f$canonical]
  ids <- setdiff(ids, "h5ad_spatial")
  if (!isTRUE(caps$SingleCellExperiment)) ids <- setdiff(ids, "sce")
  if (!isTRUE(caps$tiledbsoma)) ids <- setdiff(ids, "soma")
  ids
}

#' Targets that are legal for a given source format
#'
#' Conversion always routes through the Seurat hub, so every readable source
#' can reach every writable target. The list is still source-aware in two ways:
#' the source's own format is removed (no "convert to itself"), and targets
#' whose runtime dependency is missing are dropped (see [sc_valid_targets()]).
#'
#' @param source_id Format id detected for the input.
#' @param caps Optional result of [sc_capabilities()].
#' @return A character vector of target format ids (possibly empty).
#' @export
sc_valid_targets_for <- function(source_id, caps = sc_capabilities()) {
  if (identical(source_id, "h5ad_spatial")) source_id <- "h5ad"
  row <- sc_format_by_id(source_id)
  if (nrow(row) == 0 || !isTRUE(row$can_read[1])) return(character(0))
  if (!sc_backend_ready(caps)) return(character(0))
  setdiff(sc_valid_targets(caps), source_id)
}

#' Human-readable capability matrix
#'
#' @export
sc_format_matrix <- function() {
  f <- sc_formats()
  data.frame(
    Format = f$label,
    Id = f$id,
    Kind = f$kind,
    Ecosystem = f$ecosystem,
    Readable = ifelse(f$can_read, "yes", "-"),
    Writable = ifelse(f$can_write, "yes", "-"),
    Notes = f$notes,
    stringsAsFactors = FALSE
  )
}
