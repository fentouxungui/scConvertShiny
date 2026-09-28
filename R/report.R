# Conversion reporting and output packaging helpers.

#' Human-readable size of a file or directory
#' @noRd
sc_format_size <- function(path) {
  if (is.null(path) || !nzchar(path) || (!file.exists(path) && !dir.exists(path))) {
    return(NA_character_)
  }
  bytes <- if (dir.exists(path)) {
    sum(file.info(list.files(path, recursive = TRUE, full.names = TRUE))$size, na.rm = TRUE)
  } else {
    file.info(path)$size
  }
  if (is.na(bytes)) return(NA_character_)
  units <- c("B", "KB", "MB", "GB", "TB")
  i <- 1
  while (bytes >= 1024 && i < length(units)) {
    bytes <- bytes / 1024
    i <- i + 1
  }
  sprintf("%.2f %s", bytes, units[i])
}

#' Package a directory output into a zip file
#' @noRd
sc_package_output <- function(path, zip_dir = tempdir()) {
  if (!dir.exists(path)) return(path)
  if (!requireNamespace("zip", quietly = TRUE)) {
    stop("Packaging a directory output requires the 'zip' package.", call. = FALSE)
  }
  out <- file.path(zip_dir, paste0(basename(path), ".zip"))
  if (file.exists(out)) unlink(out)
  zip::zipr(out, files = basename(path), root = dirname(path))
  out
}

#' Build a human-readable conversion report
#'
#' @param info A list describing the conversion (see the app server for the
#'   fields used).
#' @return A single character string in Markdown format.
#' @export
sc_build_report <- function(info) {
  info <- info %||% list()
  ok <- isTRUE(info$ok)
  lines <- c(
    "# Conversion report",
    "",
    paste0("- Time: ", info$time %||% sc_now()),
    paste0("- Input: ", info$source %||% "NA"),
    paste0("- Detected format: ", info$source_label %||% info$source_id %||% "NA"),
    paste0("- Target format: ", info$target_label %||% info$target_id %||% "NA"),
    paste0("- Assay: ", info$assay %||% "RNA"),
    paste0("- Backend: ", info$backend %||% "scConvert"),
    paste0("- Status: ", if (ok) "success" else "failure"),
    paste0("- Elapsed: ", if (!is.null(info$elapsed)) sprintf("%.2f s", info$elapsed) else "NA"),
    paste0("- Output: ", info$dest %||% "NA")
  )
  if (!is.null(info$output_size) && !is.na(info$output_size)) {
    lines <- c(lines, paste0("- Output size: ", info$output_size))
  }
  if (!ok && !is.null(info$message) && nzchar(info$message)) {
    lines <- c(lines, "", "## Error", info$message)
  }
  if (!is.null(info$log) && nzchar(info$log)) {
    lines <- c(lines, "", "## Log", "```", info$log, "```")
  }
  paste(lines, collapse = "\n")
}
