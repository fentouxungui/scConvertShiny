# scConvert installation prerequisites

`scConvertShiny` itself is a pure R/Shiny package and needs no compiler. But
its dependency `scConvert` **contains C source** (`NeedsCompilation: yes` in
its `DESCRIPTION`), so installing `scConvert` from source requires a machine
with a C toolchain.

## Summary (important)

- Without `scConvert`, the app still starts: it shows the format capability
  matrix, but the conversion button is disabled and a hint is displayed.
- To run real conversions, `scConvert` must be installed first.

## Platform requirements

### Windows

1. Install the Rtools matching your R version (e.g. Rtools45 for R 4.5,
   Rtools44 for R 4.4). Download:
   https://cran.r-project.org/bin/windows/Rtools/
2. During installation, tick "Add rtools to system PATH", or verify in R with
   `pkgbuild::has_build_tools(debug = TRUE)`.
3. Key point: `make` and `gcc` must be on PATH. On Windows `make` is provided
   by Rtools.

### Linux

```sh
sudo apt-get install -y build-essential libhdf5-dev libzstd-dev
```

### macOS

```sh
xcode-select --install
brew install hdf5 zstd
```

## Installation

Run the bundled one-click script from R:

```r
source(system.file("install", "install_scConvert.R", package = "scConvertShiny"))
```

Or manually:

```r
options(repos = c(CRAN = "https://cloud.r-project.org"))
install.packages("remotes")
remotes::install_github("mianaz/scConvert", upgrade = "never")
```

## Verify after installation

```r
source(system.file("install", "verify_scConvert.R", package = "scConvertShiny"))
```

The script loads `scConvert`, builds a tiny Seurat object, writes `.h5Seurat`,
converts it to `.h5ad`, converts it back to `.h5Seurat`, and compares
dimensions to verify the whole path.

## Why it cannot be installed in the managed runtime

Measured in the Open-Science app-managed conda R environment (R 4.5.3):

- the environment has mingw-w64 `gcc 16.2.0`
  (`Library/bin/x86_64-w64-mingw32-gcc.exe`),
- but it **lacks `make` and `sh`**, and the managed installer cannot add the
  conda `m2-make` package (it is rewritten to the nonexistent `r-m2-make` and
  fails),
- therefore `R CMD INSTALL` cannot run and `scConvert` cannot be compiled there.

Workaround: install once on a machine with the toolchain above, or obtain/build
a precompiled binary and install it with
`install.packages("<scConvert_x.y.z.zip>", repos = NULL, type = "binary")`.

## Optional: C command-line accelerator (not required)

`scConvert` ships an optional C binary `scconvert` for streaming HDF5-to-HDF5
conversions (faster, constant memory). It is not required; the package falls
back to pure R. See `src/Makefile.cli` in the scConvert repository.
