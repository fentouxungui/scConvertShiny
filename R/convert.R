# Conversion dispatch.
#
# All conversions route through scConvert's public scConvert() generic. The
# single special case is the in-memory SingleCellExperiment target, which is
# serialised to RDS so it can be downloaded.
#
# Known scConvert quirk: several HDF5 "direct path" converters (e.g.
# H5ADToLoom) do not accept the `assay`/`standardize` arguments that
# scConvert() forwards to them, so they fail with "unused argument" whenever
# the optional C CLI is not built (which is the common case). We therefore
# pass `standardize` only for h5ad targets and fall back to scConvert's
# Seurat-hub path on "unused argument".

#' Convert a single-cell dataset to a target format
#'
#' @param source Path/dir/URI of the source dataset.
#' @param target_id Target format id (see [sc_formats()]).
#' @param dest_path Destination path (or directory for directory formats).
#' @param assay Assay name passed to scConvert.
#' @param overwrite Overwrite an existing destination.
#' @param standardize Standardise metadata column names when writing h5ad.
#' @param verbose Emit progress messages.
#' @param source_id Optional source format id; detected from `source` when
#'   `NULL`. Used by the hub fallback.
#' @param backend `"scConvert"` (default) or `"stub"` for testing.
#' @param ... Passed on to `scConvert::scConvert()`.
#' @return Invisibly, `dest_path`.
#' @export
sc_convert <- function(source, target_id, dest_path, assay = "RNA",
                       overwrite = TRUE, standardize = FALSE, verbose = TRUE,
                       source_id = NULL,
                       backend = getOption("scConvertShiny.backend", "scConvert"),
                       ...) {
  if (identical(backend, "stub")) {
    return(sc_convert_stub(source, target_id, dest_path))
  }
  if (!requireNamespace("scConvert", quietly = TRUE)) {
    stop(
      "scConvert is not installed; cannot convert. Run inst/install/install_scConvert.R first.",
      call. = FALSE
    )
  }

  if (identical(target_id, "sce")) {
    if (!requireNamespace("SingleCellExperiment", quietly = TRUE)) {
      stop("Converting to SingleCellExperiment requires the SingleCellExperiment package.", call. = FALSE)
    }
    obj <- scConvert::scConvert(
      source, dest = "sce", assay = assay,
      verbose = verbose, standardize = standardize
    )
    saveRDS(obj, dest_path)
    return(invisible(dest_path))
  }

  if (is.null(source_id) && is.character(source)) {
    source_id <- sc_detect_input(source)$id
  }
  sc_convert_scdispatch(
    source, source_id, target_id, dest_path,
    assay = assay, overwrite = overwrite, verbose = verbose,
    standardize = standardize
  )
}

#' Run scConvert, falling back to the Seurat-hub path when a direct-path
#' converter rejects `assay`/`standardize` with "unused argument".
#' @noRd
sc_convert_scdispatch <- function(source, source_id, target_id, dest_path,
                                  assay, overwrite, verbose, standardize) {
  # SOMA and SpatialData sources cannot go through scConvert's hub: their
  # registered loaders are declared with a `source` formal while HubConvert
  # calls the loader with `file =`, so they fail with a *different* error
  # ("argument \"source\" is missing"). Load them explicitly, then save with
  # the registered savers via scConvert(<Seurat>, dest = ...).
  if (source_id %in% c("soma", "spatialdata.zarr")) {
    obj <- if (identical(source_id, "soma")) {
      scConvert::readSOMA(source, measurement = assay, verbose = verbose)
    } else {
      scConvert::readSpatialData(source, verbose = verbose)
    }
    if (identical(target_id, "sce")) {
      if (!requireNamespace("SingleCellExperiment", quietly = TRUE)) {
        stop("Converting to SingleCellExperiment requires the SingleCellExperiment package.", call. = FALSE)
      }
      saveRDS(scConvert::scConvert(obj, dest = "sce", verbose = verbose), dest_path)
    } else {
      scConvert::scConvert(obj, dest = dest_path, overwrite = overwrite, verbose = verbose)
    }
    return(invisible(dest_path))
  }

  pass_standardize <- target_id %in% c("h5ad", "h5ad_spatial")
  ok <- tryCatch({
    if (pass_standardize) {
      scConvert::scConvert(source, dest = dest_path, assay = assay,
                           overwrite = overwrite, verbose = verbose,
                           standardize = standardize)
    } else {
      scConvert::scConvert(source, dest = dest_path, assay = assay,
                           overwrite = overwrite, verbose = verbose)
    }
    TRUE
  }, error = function(e) {
    if (!grepl("unused argument", conditionMessage(e), fixed = TRUE)) stop(e)
    FALSE
  })
  if (isTRUE(ok)) return(invisible(dest_path))

  stype <- if (identical(source_id, "h5ad_spatial")) "h5ad" else source_id
  hub <- get("HubConvert", envir = asNamespace("scConvert"))
  hub(source_file = source, dest_file = dest_path, stype = stype,
      dtype = target_id, assay = assay, overwrite = overwrite, verbose = verbose)
  invisible(dest_path)
}

#' Stub backend used for application self-tests
#' @noRd
sc_convert_stub <- function(source, target_id, dest_path) {
  is_dir_target <- target_id %in% c("zarr", "spatialdata.zarr", "soma")
  if (is_dir_target) {
    if (dir.exists(dest_path)) unlink(dest_path, recursive = TRUE)
    dir.create(dest_path, recursive = TRUE)
    writeLines(
      sprintf("stub output for %s from %s", target_id, source),
      file.path(dest_path, "STUB.txt")
    )
  } else {
    writeLines(
      sprintf("stub output for %s from %s", target_id, source),
      dest_path
    )
  }
  invisible(dest_path)
}
