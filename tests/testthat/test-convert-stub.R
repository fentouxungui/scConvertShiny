test_that("stub backend writes a single-file output", {
  src <- tempfile(fileext = ".h5ad")
  writeLines("dummy", src)
  dest <- tempfile(fileext = ".h5Seurat")
  sc_convert(src, "h5seurat", dest, backend = "stub")
  expect_true(file.exists(dest))
  expect_match(readLines(dest)[1], "stub output")
})

test_that("stub backend writes a directory output", {
  src <- tempfile(fileext = ".h5ad")
  writeLines("dummy", src)
  dest <- file.path(tempdir(), "roundtrip.zarr")
  sc_convert(src, "zarr", dest, backend = "stub")
  expect_true(dir.exists(dest))
  expect_true(file.exists(file.path(dest, "STUB.txt")))
})

test_that("async engine completes with the stub backend", {
  src <- tempfile(fileext = ".rds")
  saveRDS(list(x = 1), src)
  dest <- tempfile(fileext = ".h5ad")
  job <- sc_run_conversion_async(src, "h5ad", dest, backend = "stub")

  t0 <- Sys.time()
  while (job$process$is_alive() &&
         as.numeric(difftime(Sys.time(), t0, units = "secs")) < 30) {
    Sys.sleep(0.2)
  }
  res <- sc_poll_conversion(job)
  expect_true(isTRUE(res$done))
  expect_true(isTRUE(res$ok))
  expect_true(file.exists(dest))
})

test_that("report includes key fields", {
  rep <- sc_build_report(list(
    ok = TRUE, source = "a.h5ad", source_label = "AnnData (.h5ad)",
    target_label = "h5Seurat (.h5Seurat)", assay = "RNA",
    backend = "stub", elapsed = 1.23, dest = "a.h5Seurat",
    output_size = "1.00 KB"
  ))
  expect_match(rep, "转换报告")
  expect_match(rep, "成功")
  expect_match(rep, "1.23 s")
})
