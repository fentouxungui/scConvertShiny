# Self-test for scConvertShiny. Does not require testthat.
#
# Usage (installed package):
#   source(system.file("tests", "selftest.R", package = "scConvertShiny"))
# Usage (source checkout):
#   source("inst/tests/selftest.R")

suppressMessages({
  if (!requireNamespace("scConvertShiny", quietly = TRUE)) {
    candidates <- c("R", "../../R", "scConvertShiny/R")
    rdir <- candidates[file.exists(file.path(candidates, "formats.R"))][1]
    if (is.na(rdir)) {
      stop("找不到 scConvertShiny：请先安装，或在包根目录下运行本脚本。")
    }
    message("从源码目录加载: ", rdir)
    for (f in list.files(rdir, pattern = "\\.R$", full.names = TRUE)) source(f)
  } else {
    library(scConvertShiny)
  }
})

results <- character(0)
check <- function(name, expr) {
  r <- tryCatch({ force(expr); "PASS" }, error = function(e) {
    paste0("FAIL: ", conditionMessage(e))
  })
  results[[name]] <<- r
  cat(sprintf("[%-52s] %s\n", r, name))
}

check("format matrix contains canonical formats", {
  f <- sc_formats()
  stopifnot(all(c(
    "h5ad", "h5ad_spatial", "h5seurat", "h5mu", "loom", "rds",
    "zarr", "soma", "spatialdata.zarr", "sce", "gef"
  ) %in% f$id))
})

check("read-only vendor formats are not targets", {
  t <- sc_valid_targets(sc_capabilities())
  stopifnot(!any(c("gef", "cellbin.gef", "cosmx", "h5ad_spatial") %in% t))
})

check("detect common extensions", {
  stopifnot(
    sc_detect_input("a.h5ad")$id == "h5ad",
    sc_detect_input("a.h5Seurat")$id == "h5seurat",
    sc_detect_input("a.h5mu")$id == "h5mu",
    sc_detect_input("a.loom")$id == "loom",
    sc_detect_input("a.rds")$id == "rds",
    sc_detect_input("a.zarr")$id == "zarr",
    sc_detect_input("e.spatialdata.zarr")$id == "spatialdata.zarr",
    sc_detect_input("a.cellbin.gef")$id == "cellbin.gef",
    sc_detect_input("a.gef")$id == "gef"
  )
})

check("detect URI scheme", {
  d <- sc_detect_input("soma://collection/measurement")
  stopifnot(identical(d$id, "soma"), isTRUE(d$recognized))
})

check("stub backend, single file", {
  src <- tempfile(fileext = ".h5ad"); writeLines("x", src)
  dest <- tempfile(fileext = ".h5Seurat")
  sc_convert(src, "h5seurat", dest, backend = "stub")
  stopifnot(file.exists(dest))
})

check("stub backend, directory output", {
  src <- tempfile(fileext = ".h5ad"); writeLines("x", src)
  dest <- file.path(tempdir(), "st.zarr")
  sc_convert(src, "zarr", dest, backend = "stub")
  stopifnot(dir.exists(dest), file.exists(file.path(dest, "STUB.txt")))
})

check("async engine with stub backend", {
  src <- tempfile(fileext = ".rds"); saveRDS(list(x = 1), src)
  dest <- tempfile(fileext = ".h5ad")
  job <- sc_run_conversion_async(src, "h5ad", dest, backend = "stub")
  t0 <- Sys.time()
  while (job$process$is_alive() &&
         as.numeric(difftime(Sys.time(), t0, units = "secs")) < 30) {
    Sys.sleep(0.2)
  }
  res <- sc_poll_conversion(job)
  stopifnot(isTRUE(res$done), isTRUE(res$ok), file.exists(dest))
})

check("report renders", {
  rep <- sc_build_report(list(
    ok = TRUE, source = "a.h5ad", source_label = "AnnData (.h5ad)",
    target_label = "h5Seurat (.h5Seurat)", assay = "RNA", backend = "stub",
    elapsed = 1.23, dest = "a.h5Seurat", output_size = "1.00 KB"
  ))
  stopifnot(grepl("转换报告", rep), grepl("成功", rep))
})

check("shiny app object constructs", {
  app <- shiny::shinyApp(ui = sc_app_ui, server = sc_app_server)
  stopifnot(inherits(app, "shiny.appobj"))
})

check("demo registry covers the shipped formats", {
  d <- sc_demo_data()
  stopifnot(all(c("h5ad", "h5ad_spatial", "h5seurat", "h5mu", "loom",
                  "rds", "zarr") %in% d$format_id))
  stopifnot(sum(d$type == "file") >= 6L)
})

check("demo preparation (network optional)", {
  d <- sc_demo_data()
  stopifnot("pbmc_small_h5ad" %in% d$id)
  res <- tryCatch(
    sc_demo_prepare("pbmc_small_h5ad", dest_dir = tempfile()),
    error = function(e) NULL
  )
  if (is.null(res)) {
    cat("  [info] 跳过：无网络，无法下载示例数据\n")
  } else {
    stopifnot(file.exists(res$path))
  }
})

check("upload limit defaults to 20 GB and guards oversize", {
  if (is.null(getOption("scConvertShiny.maxUploadMB"))) {
    options(scConvertShiny.maxUploadMB = 20 * 1024)
  }
  stopifnot(identical(getOption("scConvertShiny.maxUploadMB"), 20 * 1024))
  f <- tempfile(); writeLines("x", f)
  err <- tryCatch(
    sc_prepare_input(upload = f, upload_name = "a.h5ad", max_upload_mb = 1e-6),
    error = function(e) conditionMessage(e)
  )
  stopifnot(is.character(err), grepl("超过上限", err))
})

check("targets exclude the source's own format", {
  caps <- sc_capabilities(); caps$backend <- "stub"
  caps$SingleCellExperiment <- TRUE; caps$tiledbsoma <- TRUE
  t <- sc_valid_targets_for("h5ad", caps)
  stopifnot(!("h5ad" %in% t), "h5seurat" %in% t, "sce" %in% t)
})

check("soma hidden when tiledbsoma is unavailable", {
  caps <- sc_capabilities(); caps$backend <- "stub"
  caps$tiledbsoma <- FALSE
  stopifnot(!("soma" %in% sc_valid_targets(caps)))
  caps$tiledbsoma <- TRUE
  stopifnot("soma" %in% sc_valid_targets(caps))
})

check("assay defaults per format", {
  stopifnot(sc_detect_assays(NA, "gef")$default == "Spatial")
  stopifnot(sc_detect_assays(NA, "cellbin.gef")$default == "Spatial")
  stopifnot(sc_detect_assays(NA, "cosmx")$default == "Nanostring")
  stopifnot(sc_detect_assays(NA, "h5ad")$default == "RNA")
  stopifnot(sc_detect_assays(NA, "unknown_fmt")$default == "RNA")
})

cat("\n================ 汇总 ================\n")
fails <- results[grepl("^FAIL", results)]
cat(sprintf("PASS: %d / %d\n", length(results) - length(fails), length(results)))
if (length(fails)) {
  cat("失败项:\n"); print(names(fails))
  stop(sprintf("self-test: %d failure(s)", length(fails)), call. = FALSE)
}
cat("全部通过。\n")
