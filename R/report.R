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
    stop("打包目录型输出需要安装 'zip' 包。", call. = FALSE)
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
    "# 转换报告",
    "",
    paste0("- 时间: ", info$time %||% sc_now()),
    paste0("- 输入: ", info$source %||% "NA"),
    paste0("- 检测格式: ", info$source_label %||% info$source_id %||% "NA"),
    paste0("- 目标格式: ", info$target_label %||% info$target_id %||% "NA"),
    paste0("- Assay: ", info$assay %||% "RNA"),
    paste0("- 后端: ", info$backend %||% "scConvert"),
    paste0("- 状态: ", if (ok) "成功" else "失败"),
    paste0("- 耗时: ", if (!is.null(info$elapsed)) sprintf("%.2f s", info$elapsed) else "NA"),
    paste0("- 输出: ", info$dest %||% "NA")
  )
  if (!is.null(info$output_size) && !is.na(info$output_size)) {
    lines <- c(lines, paste0("- 输出大小: ", info$output_size))
  }
  if (!ok && !is.null(info$message) && nzchar(info$message)) {
    lines <- c(lines, "", "## 错误", info$message)
  }
  if (!is.null(info$log) && nzchar(info$log)) {
    lines <- c(lines, "", "## 日志", "```", info$log, "```")
  }
  paste(lines, collapse = "\n")
}
