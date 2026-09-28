test_that("detect known file extensions", {
  expect_equal(sc_detect_input("sample.h5ad")$id, "h5ad")
  expect_equal(sc_detect_input("sample.h5Seurat")$id, "h5seurat")
  expect_equal(sc_detect_input("sample.h5mu")$id, "h5mu")
  expect_equal(sc_detect_input("sample.loom")$id, "loom")
  expect_equal(sc_detect_input("sample.rds")$id, "rds")
  expect_equal(sc_detect_input("sample.zarr")$id, "zarr")
  expect_equal(sc_detect_input("experiment.spatialdata.zarr")$id, "spatialdata.zarr")
  expect_equal(sc_detect_input("sample.cellbin.gef")$id, "cellbin.gef")
  expect_equal(sc_detect_input("sample.gef")$id, "gef")
})

test_that("detect URI schemes", {
  d <- sc_detect_input("soma://collection/measurement")
  expect_equal(d$id, "soma")
  expect_true(d$recognized)
  expect_true(is.na(d$exists))
})

test_that("unknown extensions are not recognized", {
  d <- sc_detect_input("notes.txt")
  expect_false(d$recognized)
  expect_false(d$can_read)
})

test_that("empty path returns NULL", {
  expect_null(sc_detect_input(""))
  expect_null(sc_detect_input(NULL))
})

test_that("assay defaults per format", {
  expect_equal(sc_detect_assays(NA, "gef")$default, "Spatial")
  expect_equal(sc_detect_assays(NA, "cellbin.gef")$default, "Spatial")
  expect_equal(sc_detect_assays(NA, "cosmx")$default, "Nanostring")
  expect_equal(sc_detect_assays(NA, "h5ad")$default, "RNA")
})
