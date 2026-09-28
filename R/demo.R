# Demo datasets bundled in the scConvert repository.
#
# scConvert does not publish per-format download links; instead it ships a
# small set of example files inside its own package (inst/extdata and
# inst/testdata). We expose them for one-click loading: prefer the local copy
# when scConvert is installed, otherwise download from GitHub raw.

.sc_demo_base_url <- "https://raw.githubusercontent.com/mianaz/scConvert/main"

#' Demo datasets shipped with scConvert
#'
#' @return A data.frame with `id`, `label`, `format_id`, `type`
#'   (`"file"` downloadable or `"derived"` generated with scConvert),
#'   `repo_path`, `base_id` and `size_mb`.
#' @export
sc_demo_data <- function() {
  data.frame(
    id = c(
      "pbmc_h5ad", "pbmc_spatial_h5ad", "pbmc_h5seurat", "pbmc_loom",
      "citeseq_h5mu", "pbmc_rds", "pbmc_small_h5ad", "pbmc_small_rds",
      "zarr_from_h5ad"
    ),
    label = c(
      "PBMC 500 cells — AnnData (.h5ad)",
      "Visium mouse brain — Spatial AnnData (.h5ad)",
      "PBMC 500 cells — h5Seurat (.h5seurat)",
      "PBMC 500 cells — Loom (.loom)",
      "CITE-seq — MuData (.h5mu)",
      "PBMC 500 cells — RDS (.rds)",
      "PBMC small — AnnData (.h5ad)",
      "PBMC small — RDS (.rds)",
      "Zarr (generated from pbmc_demo.h5ad)"
    ),
    format_id = c(
      "h5ad", "h5ad_spatial", "h5seurat", "loom", "h5mu", "rds",
      "h5ad", "rds", "zarr"
    ),
    type = c(rep("file", 8L), "derived"),
    repo_path = c(
      "inst/extdata/pbmc_demo.h5ad",
      "inst/extdata/spatial_demo.h5ad",
      "inst/extdata/pbmc_demo.h5seurat",
      "inst/extdata/pbmc_demo.loom",
      "inst/extdata/citeseq_demo.h5mu",
      "inst/extdata/pbmc_demo.rds",
      "inst/testdata/pbmc_small.h5ad",
      "inst/testdata/pbmc_small.rds",
      NA_character_
    ),
    base_id = c(rep(NA_character_, 8L), "pbmc_h5ad"),
    size_mb = c(0.93, 3.23, 2.16, 2.17, 0.74, 1.57, 0.56, 1.42, NA_real_),
    stringsAsFactors = FALSE
  )
}

#' Locate a demo file inside an installed scConvert package
#' @noRd
sc_demo_local_path <- function(repo_path) {
  if (!requireNamespace("scConvert", quietly = TRUE)) return(NULL)
  parts <- strsplit(repo_path, "/", fixed = TRUE)[[1]] # inst/<folder>/<file>
  if (length(parts) < 3) return(NULL)
  p <- system.file(parts[2], parts[3], package = "scConvert")
  if (nzchar(p) && file.exists(p)) p else NULL
}

#' Prepare a demo dataset, returning a local path
#'
#' Uses the copy bundled with an installed scConvert when available; otherwise
#' downloads the file from the scConvert GitHub repository (requires network).
#' `type = "derived"` demos are generated with scConvert from a base demo.
#'
#' @param id Demo id from [sc_demo_data()].
#' @param dest_dir Directory to place the downloaded/generated data in.
#' @param caps Optional result of [sc_capabilities()].
#' @return A list with `path`, `cleanup`, `origin`, `label`, `format_id`.
#' @export
sc_demo_prepare <- function(id, dest_dir = tempdir(), caps = sc_capabilities()) {
  d <- sc_demo_data()
  row <- d[match(id, d$id), , drop = FALSE]
  if (nrow(row) == 0) stop("Unknown demo dataset: ", id, call. = FALSE)

  if (identical(row$type[1], "derived")) {
    return(sc_demo_derive(row$id[1], row$base_id[1], row$format_id[1], dest_dir, caps))
  }

  dest <- file.path(dest_dir, basename(row$repo_path[1]))
  local <- sc_demo_local_path(row$repo_path[1])
  if (!is.null(local)) {
    if (!file.copy(local, dest, overwrite = TRUE)) {
      stop("Could not copy the local demo file.", call. = FALSE)
    }
  } else {
    url <- paste0(.sc_demo_base_url, "/", row$repo_path[1])
    ok <- FALSE
    tryCatch({
      suppressWarnings(utils::download.file(url, dest, mode = "wb", quiet = TRUE))
      ok <- file.exists(dest) && file.info(dest)$size > 0
    }, error = function(e) NULL)
    if (!isTRUE(ok)) {
      stop(
        "Failed to download the demo data (network access to GitHub is required). ",
        "Use the local-path mode to pick a file manually, or install scConvert to use its bundled demos.",
        call. = FALSE
      )
    }
  }
  list(
    path = dest, cleanup = dest, origin = "demo",
    label = row$label[1], format_id = row$format_id[1], demo_id = id
  )
}

#' Generate a derived demo dataset with scConvert
#' @noRd
sc_demo_derive <- function(id, base_id, format_id, dest_dir, caps = sc_capabilities()) {
  if (!sc_backend_ready(caps)) {
    stop("Generating a derived demo (e.g. Zarr) requires scConvert.", call. = FALSE)
  }
  base <- sc_demo_prepare(base_id, dest_dir = dest_dir, caps = caps)
  dest <- file.path(dest_dir, paste0("demo_", gsub("\\.", "_", format_id), ".zarr"))
  if (dir.exists(dest)) unlink(dest, recursive = TRUE)
  sc_convert(base$path, format_id, dest, backend = caps$backend, verbose = FALSE)
  list(
    path = dest, cleanup = c(base$cleanup, dest), origin = "demo",
    label = paste0("Derived demo: ", format_id), format_id = format_id, demo_id = id
  )
}
