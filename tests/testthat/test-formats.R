test_that("format matrix covers the canonical formats", {
  f <- sc_formats()
  expect_true(all(c(
    "h5ad", "h5ad_spatial", "h5seurat", "h5mu", "loom", "rds",
    "zarr", "soma", "spatialdata.zarr", "sce", "gef"
  ) %in% f$id))
  expect_equal(sum(f$canonical), 12L)
  expect_true("cosmx" %in% f$id)
})

test_that("read-only vendor formats are never targets", {
  targets <- sc_valid_targets(sc_capabilities())
  expect_false(any(c("gef", "cellbin.gef", "cosmx") %in% targets))
  expect_false("h5ad_spatial" %in% targets)
})

test_that("sce target depends on SingleCellExperiment", {
  caps <- sc_capabilities()
  caps$SingleCellExperiment <- FALSE
  expect_false("sce" %in% sc_valid_targets(caps))
  caps$SingleCellExperiment <- TRUE
  expect_true("sce" %in% sc_valid_targets(caps))
})

test_that("valid targets require a ready backend", {
  caps <- sc_capabilities()
  caps$scConvert <- FALSE
  caps$backend <- "scConvert"
  expect_length(sc_valid_targets_for("h5ad", caps), 0L)
  caps$backend <- "stub"
  expect_gt(length(sc_valid_targets_for("h5ad", caps)), 0L)
})

test_that("unrecognized source has no targets", {
  caps <- sc_capabilities()
  caps$backend <- "stub"
  expect_length(sc_valid_targets_for("not_a_real_format", caps), 0L)
})

test_that("targets exclude the source's own format", {
  caps <- sc_capabilities()
  caps$backend <- "stub"
  caps$SingleCellExperiment <- TRUE
  caps$tiledbsoma <- TRUE
  t <- sc_valid_targets_for("h5ad", caps)
  expect_false("h5ad" %in% t)
  expect_true("h5seurat" %in% t)
})

test_that("soma target requires tiledbsoma", {
  caps <- sc_capabilities()
  caps$tiledbsoma <- FALSE
  expect_false("soma" %in% sc_valid_targets(caps))
  caps$tiledbsoma <- TRUE
  expect_true("soma" %in% sc_valid_targets(caps))
})
