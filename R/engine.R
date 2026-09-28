# Asynchronous conversion engine.
#
# Conversions can take minutes and consume a lot of memory, so they run in a
# detached callr background process. The child is self-contained (it does not
# assume scConvertShiny is installed) and returns a small status list.

#' Conversion worker executed in the background process
#' @noRd
sc_conversion_worker <- function(source, target_id, dest_path, assay,
                                 standardize, verbose, backend) {
  tryCatch({
    if (identical(backend, "stub")) {
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
      return(list(ok = TRUE, message = "stub conversion complete", dest = dest_path))
    }

    if (!requireNamespace("scConvert", quietly = TRUE)) {
      stop("scConvert 未安装", call. = FALSE)
    }
    if (identical(target_id, "sce")) {
      if (!requireNamespace("SingleCellExperiment", quietly = TRUE)) {
        stop("SingleCellExperiment 未安装", call. = FALSE)
      }
      obj <- scConvert::scConvert(
        source, dest = "sce", assay = assay,
        verbose = verbose, standardize = standardize
      )
      saveRDS(obj, dest_path)
    } else {
      scConvert::scConvert(
        source, dest = dest_path, assay = assay, overwrite = TRUE,
        verbose = verbose, standardize = standardize
      )
    }
    list(ok = TRUE, message = "conversion complete", dest = dest_path)
  }, error = function(e) {
    list(ok = FALSE, message = conditionMessage(e), dest = dest_path)
  })
}

#' Launch a conversion in a background R process
#'
#' @inheritParams sc_convert
#' @param log_path File to capture child stdout/stderr.
#' @return A list with `process` (a `callr::r_bg` handle) and `log_path`.
#' @export
sc_run_conversion_async <- function(source, target_id, dest_path, assay = "RNA",
                                    standardize = FALSE, verbose = TRUE,
                                    backend = getOption("scConvertShiny.backend", "scConvert"),
                                    log_path = NULL) {
  if (is.null(log_path)) {
    log_path <- tempfile("scconvert_", fileext = ".log")
  }
  # Make the worker fully self-contained (base + explicit `::` calls only) so
  # the child process never depends on this package's namespace being loaded.
  worker <- sc_conversion_worker
  environment(worker) <- baseenv()
  proc <- callr::r_bg(
    func = worker,
    args = list(
      source = source, target_id = target_id, dest_path = dest_path,
      assay = assay, standardize = standardize, verbose = verbose,
      backend = backend
    ),
    supervise = TRUE,
    poll_connection = FALSE,
    stdout = log_path,
    stderr = log_path
  )
  list(process = proc, log_path = log_path)
}

#' Poll a background conversion job
#'
#' @param job The list returned by [sc_run_conversion_async()].
#' @return A list with `done`; once done, also `ok`, `message`, `dest`, `log`
#'   and `log_path`.
#' @export
sc_poll_conversion <- function(job) {
  p <- job$process
  if (isTRUE(p$is_alive())) return(list(done = FALSE))
  res <- tryCatch(
    p$get_result(),
    error = function(e) list(ok = FALSE, message = conditionMessage(e), dest = NA_character_)
  )
  res$log <- if (file.exists(job$log_path)) {
    paste(readLines(job$log_path, warn = FALSE), collapse = "\n")
  } else {
    ""
  }
  res$log_path <- job$log_path
  res$done <- TRUE
  res
}
