# Input staging for browser uploads and local paths.

# Upload size limit (default 20 GB), configurable via
# options(scConvertShiny.maxUploadMB = <MB>).
#' @noRd
sc_max_upload_mb <- function() {
  as.numeric(getOption("scConvertShiny.maxUploadMB", 20 * 1024))
}

#' @noRd
sc_max_upload_bytes <- function() {
  sc_max_upload_mb() * 1024^2
}

#' Stage a conversion input
#'
#' Browser uploads are copied into a temporary directory (and unzipped when a
#' `.zip` was uploaded for a directory-based format). Local paths and URIs are
#' used in place. Large files should always use `path` rather than `upload`.
#'
#' @param upload Path to an uploaded temporary file (from `fileInput`).
#' @param path User-supplied local path or URI.
#' @param upload_name Original filename of the upload, used to keep the real
#'   extension which `fileInput`'s `datapath` does not preserve.
#' @param dest_dir Directory to stage uploads into.
#' @param max_upload_mb Maximum accepted upload size in megabytes; defaults to
#'   `getOption("scConvertShiny.maxUploadMB", 20 * 1024)`.
#' @return A list with `path`, `origin` and `cleanup` (paths to delete later).
#' @export
sc_prepare_input <- function(upload = NULL, path = NULL, upload_name = NULL,
                             dest_dir = tempdir(),
                             max_upload_mb = sc_max_upload_mb()) {
  cleanup <- character(0)

  if (!is.null(upload) && nzchar(upload)) {
    if (!file.exists(upload)) stop("The uploaded temporary file was not found.", call. = FALSE)
    size_mb <- file.info(upload)$size / 1024^2
    if (!is.na(size_mb) && size_mb > max_upload_mb) {
      stop(sprintf(
        "Uploaded file is about %.0f MB, exceeding the %d MB limit; please use the local-path mode.",
        size_mb, as.integer(max_upload_mb)
      ), call. = FALSE)
    }
    staged <- file.path(dest_dir, upload_name %||% basename(upload))
    if (!file.copy(upload, staged, overwrite = TRUE)) {
      stop("Could not stage the uploaded file.", call. = FALSE)
    }
    cleanup <- c(cleanup, staged)

    if (grepl("\\.zip$", staged, ignore.case = TRUE)) {
      exdir <- file.path(dest_dir, paste0("unzip_", basename(tempfile(""))))
      utils::unzip(staged, exdir = exdir)
      cleanup <- c(cleanup, exdir)
      entries <- list.files(exdir, full.names = TRUE)
      target <- if (length(entries) == 1 && dir.exists(entries[1])) {
        entries[1]
      } else {
        exdir
      }
      return(list(path = target, origin = "upload", cleanup = cleanup))
    }
    return(list(path = staged, origin = "upload", cleanup = cleanup))
  }

  if (!is.null(path) && nzchar(path)) {
    p <- trimws(path)
    if (!grepl("://", p) && !file.exists(p) && !dir.exists(p)) {
      stop("Path not found: ", p, call. = FALSE)
    }
    return(list(path = p, origin = "path", cleanup = character(0)))
  }

  stop("No input file or path was provided.", call. = FALSE)
}
