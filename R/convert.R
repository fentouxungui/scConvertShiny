# Conversion dispatch.
#
# All conversions route through scConvert's public scConvert() generic. The
# single special case is the in-memory SingleCellExperiment target, which is
# serialised to RDS so it can be downloaded.

#' Convert a single-cell dataset to a target format
#'
#' @param source Path/dir/URI of the source dataset.
#' @param target_id Target format id (see [sc_formats()]).
#' @param dest_path Destination path (or directory for directory formats).
#' @param assay Assay name passed to scConvert.
#' @param overwrite Overwrite an existing destination.
#' @param standardize Standardise metadata column names when writing h5ad.
#' @param verbose Emit progress messages.
#' @param backend `"scConvert"` (default) or `"stub"` for testing.
#' @param ... Passed on to `scConvert::scConvert()`.
#' @return Invisibly, `dest_path`.
#' @export
sc_convert <- function(source, target_id, dest_path, assay = "RNA",
                       overwrite = TRUE, standardize = FALSE, verbose = TRUE,
                       backend = getOption("scConvertShiny.backend", "scConvert"),
                       ...) {
  if (identical(backend, "stub")) {
    return(sc_convert_stub(source, target_id, dest_path))
  }
  if (!requireNamespace("scConvert", quietly = TRUE)) {
    stop(
      "scConvert 未安装，无法执行转换。请先运行 inst/install/install_scConvert.R。",
      call. = FALSE
    )
  }

  if (identical(target_id, "sce")) {
    if (!requireNamespace("SingleCellExperiment", quietly = TRUE)) {
      stop("转换到 SingleCellExperiment 需要安装 SingleCellExperiment 包。", call. = FALSE)
    }
    obj <- scConvert::scConvert(
      source, dest = "sce", assay = assay,
      verbose = verbose, standardize = standardize
    )
    saveRDS(obj, dest_path)
    return(invisible(dest_path))
  }

  scConvert::scConvert(
    source, dest = dest_path, assay = assay, overwrite = overwrite,
    verbose = verbose, standardize = standardize, ...
  )
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
