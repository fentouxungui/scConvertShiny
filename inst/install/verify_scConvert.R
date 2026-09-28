# Verification script for the `scConvert` dependency of scConvertShiny.
#
# Builds a tiny Seurat object and round-trips it:
#   Seurat -> .h5Seurat -> .h5ad -> .h5Seurat
# and checks that dimensions are preserved. Run from an R session:
#   source("verify_scConvert.R")

cat("== scConvertShiny: verifying scConvert ==\n")

if (!requireNamespace("scConvert", quietly = TRUE)) {
  stop("scConvert is not installed. Run install_scConvert.R first.", call. = FALSE)
}
if (!requireNamespace("Seurat", quietly = TRUE)) {
  stop("Seurat is not installed.", call. = FALSE)
}

suppressPackageStartupMessages(library(Seurat))
cat("scConvert ", as.character(utils::packageVersion("scConvert")), "\n", sep = "")
cat("Seurat    ", as.character(utils::packageVersion("Seurat")), "\n", sep = "")

# Minimal 20 genes x 10 cells Seurat object
set.seed(1)
counts <- matrix(
  rpois(200, lambda = 2), nrow = 20, ncol = 10,
  dimnames = list(paste0("g", 1:20), paste0("c", 1:10))
)
obj <- CreateSeuratObject(counts = as(counts, "dgCMatrix"))
obj$group <- rep(c("a", "b"), each = 5)

td <- tempfile("scverify_")
dir.create(td)
on.exit(unlink(td, recursive = TRUE), add = TRUE)

h5s <- file.path(td, "input.h5Seurat")
h5a <- file.path(td, "output.h5ad")
h5s2 <- file.path(td, "roundtrip.h5Seurat")

ok <- TRUE
run <- function(label, expr) {
  cat("  - ", label, " ... ", sep = "")
  tryCatch({
    force(expr)
    cat("OK\n")
  }, error = function(e) {
    ok <<- FALSE
    cat("FAILED: ", conditionMessage(e), "\n", sep = "")
  })
}

run("Seurat -> h5Seurat", {
  scConvert::scConvert(obj, dest = h5s, overwrite = TRUE, verbose = FALSE)
  stopifnot(file.exists(h5s))
})

run("h5Seurat -> h5ad", {
  scConvert::scConvert(h5s, dest = h5a, overwrite = TRUE, verbose = FALSE)
  stopifnot(file.exists(h5a))
})

run("h5ad -> h5Seurat", {
  scConvert::scConvert(h5a, dest = h5s2, overwrite = TRUE, verbose = FALSE)
  stopifnot(file.exists(h5s2))
})

run("dimensions preserved", {
  back <- scConvert::readH5Seurat(h5s2)
  stopifnot(all(dim(back) == dim(obj)))
})

if (ok) {
  cat("RESULT: scConvert round-trip verified successfully.\n")
} else {
  cat("RESULT: verification found failures (see above).\n")
  quit(status = 1)
}
