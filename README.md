# scConvertShiny

A `shinydashboard` app that wraps the format-conversion capabilities of
[`scConvert`](https://github.com/mianaz/scConvert) in a three-step wizard:

1. Choose input (small file upload, or a local path for large files / directories);
2. Pick a legal target format based on the detected input;
3. Convert asynchronously and download the result, together with a conversion report.

Conversions route through the Seurat hub; `h5ad <-> h5Seurat` uses scConvert's
direct HDF5 path.

## Supported formats

| Format | Id | Kind | Read | Write |
| --- | --- | --- | --- | --- |
| AnnData | `h5ad` | file | yes | yes |
| Spatial AnnData | `h5ad_spatial` | file | yes | yes (automatic) |
| h5Seurat | `h5seurat` | file | yes | yes |
| MuData | `h5mu` | file | yes | yes |
| Loom | `loom` | file | yes | yes |
| RDS | `rds` | file | yes | yes |
| Zarr | `zarr` | directory | yes | yes |
| TileDB-SOMA | `soma` | URI | yes | yes |
| SpatialData | `spatialdata.zarr` | directory | yes | yes |
| SingleCellExperiment | `sce` | in-memory | - | yes (saved as `.sce.rds`) |
| Stereo-seq GEF | `gef` / `cellbin.gef` | file | yes | - |

Additional read-only support: NanoString CosMx directory (`cosmx`).
The full matrix is available on the app's "Format matrix" tab
(`sc_format_matrix()`).

The target dropdown adapts to the input:

- the input's own format is excluded (no convert-to-itself);
- `sce` is hidden when `SingleCellExperiment` is not installed, and `soma`
  when `tiledbsoma` is not installed;
- all other writable formats are offered for any recognized input (scConvert
  uses Seurat as a hub, so any source -> target is valid).

### Assay name

The `Assay name` field is an auto-detected dropdown: h5Seurat lists the assays
under `/assays`, MuData lists `/mod` modalities (`rna` -> `RNA`,
`prot` -> `ADT`); other formats get a sensible default (usually `RNA`;
`Spatial` for Stereo-seq GEF, `Nanostring` for CosMx). A custom name can still
be typed. Interface: `sc_detect_assays(path, source_id)`.

## Built-in demo data

The input step offers a "Demo data" mode that loads example files shipped in
the scConvert repository:

| Demo | Format | Source |
| --- | --- | --- |
| PBMC 500 cells | AnnData `h5ad` | `inst/extdata/pbmc_demo.h5ad` |
| Visium mouse brain | Spatial AnnData | `inst/extdata/spatial_demo.h5ad` |
| PBMC 500 cells | h5Seurat | `inst/extdata/pbmc_demo.h5seurat` |
| PBMC 500 cells | Loom | `inst/extdata/pbmc_demo.loom` |
| CITE-seq | MuData `h5mu` | `inst/extdata/citeseq_demo.h5mu` |
| PBMC 500 cells | RDS | `inst/extdata/pbmc_demo.rds` |
| Zarr | Zarr | generated from `pbmc_demo.h5ad` by scConvert |

- If scConvert is installed, its bundled copy is used (no network needed);
- otherwise the file is downloaded from GitHub raw (0.6-3.2 MB, first use);
- there is no ready-made Zarr file, so it is derived from `pbmc_demo.h5ad`.

Interface: `sc_demo_data()` lists the demos,
`sc_demo_prepare("pbmc_small_h5ad")` prepares one locally and returns its path.

## Install

```r
# remotes::install_github("<your-fork>/scConvertShiny") or local install
install.packages("scConvertShiny", repos = NULL, type = "source")
```

`scConvert` is an optional runtime dependency: without it the app still starts,
but conversion is disabled. Installing `scConvert` needs a C toolchain (Rtools
on Windows, build-essential on Linux, Xcode CLT on macOS); see
`inst/install/INSTALL_PREREQUISITES.md`:

```r
source(system.file("install", "install_scConvert.R", package = "scConvertShiny"))
source(system.file("install", "verify_scConvert.R", package = "scConvertShiny"))
```

## Open as an RStudio project

The package root already contains `scConvertShiny.Rproj`:

1. RStudio -> `File` -> `Open Project...`, choose `scConvertShiny.Rproj`;
2. or double-click `scConvertShiny.Rproj`.

If there is no `.Rproj`, use `File` -> `New Project...` -> `Existing Directory`,
select the `scConvertShiny` folder, and click `Create Project`.

Once open (the Build pane recognizes it as an R package):

- `Build` -> `Install and Restart` (or `devtools::install()` in the console);
- `devtools::load_all()` loads the package for development;
- then run `run_app()` below.

## Run

```r
library(scConvertShiny)
run_app()
```

## Programming interface

The core logic is reusable without launching the UI:

```r
sc_capabilities()                 # dependency detection
sc_formats()                      # format capability matrix (data.frame)
sc_detect_input("sample.h5ad")    # input format detection
sc_detect_assays("a.h5seurat", "h5seurat")  # assay names
sc_valid_targets_for("h5ad")      # legal target formats
sc_convert("sample.h5ad", "h5seurat", "sample.h5Seurat")  # synchronous convert
```

## Tests

```r
# unit tests (testthat)
testthat::test_dir("tests/testthat")

# or the bundled self-test (no testthat needed) covering detection / matrix /
# async stub backend end-to-end
source(system.file("tests", "selftest.R", package = "scConvertShiny"))
```

Setting `options(scConvertShiny.backend = "stub")` enables a stub backend so
the whole UI flow can run without scConvert.

## Desktop build (optional)

`.github/workflows/build-desktop.yml` builds unsigned Windows/macOS installers
with [`shinyelectron`](https://github.com/fentouxungui/shinyelectron) (the
fork), mirroring the SeuratExplorer setup:

```
build-pkg (source tarball) -> build (Windows + macOS installers) -> release (on v* tags)
```

Push a `v*` tag, or run it manually from the Actions tab. Locally:

```r
pak::pak("fentouxungui/shinyelectron")
Rscript Build-Desktop-software-by-shinyelectron.R
```

`app.R` uses `sc_app()`, which returns the Shiny app object (shinyelectron runs
it) and keeps the 20 GB upload limit.

Icons: the chosen icon (candidate `02_contain_white`) is installed at
`icons/ico/scConvertShiny.ico` (Windows) and `icons/mac/scConvertShiny.icns`
plus `.png` (macOS); the build script prefers the `.icns` on macOS. To
regenerate or pick another, run `python icons/make_icons.py` (needs `pillow`)
to rebuild the grid in `icons/generated/` (`preview.png` plus per-candidate
PNG/ICO/1024px), then copy the chosen files into `icons/ico/` and `icons/mac/`.

Note: `scConvert` contains C source and is not on CRAN, so the bundled runtime
must compile it. It is listed in `dependency/` as `scConvert_*.tar.gz`
(or `scConvert-*.tar.gz`). Its configure step needs HDF5; the build config
therefore installs `hdf5r` (which bundles HDF5) as an `extra_package`, and the
macOS workflow also installs a system HDF5 as a fallback.

## Known limitations

- `scConvert` contains C source; installing from source needs a toolchain.
  A pure web-hosted environment without `make`/`gcc` cannot install it.
- Directory outputs (`zarr` / `spatialdata.zarr` / `soma`) are zipped
  automatically on download.
- Browser uploads default to a 20 GB per-file limit: `run_app()` sets
  `shiny.maxRequestSize` accordingly; adjust with
  `options(scConvertShiny.maxUploadMB = <MB>)`, or override per call with
  `sc_prepare_input(max_upload_mb = )`. For larger files or directory formats
  use the local-path mode.
- `SingleCellExperiment` is an in-memory target; this app saves it as
  `<name>.sce.rds`.

## License

MIT.
