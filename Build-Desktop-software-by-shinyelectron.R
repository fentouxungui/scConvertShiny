# Build the scConvertShiny desktop app with shinyelectron.
#
# Runs both locally (Rscript) and in GitHub Actions. It uses the fork of
# shinyelectron that supports `dependencies.r.local_packages` and `updates`:
#
#   pak::pak("fentouxungui/shinyelectron")
#
# Local use:  Rscript Build-Desktop-software-by-shinyelectron.R
# CI use:     GITHUB_WORKSPACE, APP_VERSION and GITHUB_REPOSITORY are set by CI.
#
# Repository layout expected:
#   DESCRIPTION, R/, ...                        (the R package)
#   dependency/scConvertShiny_<version>.tar.gz  (built by the build-pkg job)
#   dependency/scConvert_<version>.tar.gz       (optional; see below)
#   icons/ico/<name>.ico                        (Windows icon; optional)
#   icons/mac/<name>.png|.icns                  (macOS icon; optional)

library(shinyelectron)

# ---- paths (CI-aware) -------------------------------------------------
ws <- Sys.getenv("GITHUB_WORKSPACE", unset = getwd())
app_dir    <- file.path(ws, "build-app")
output_dir <- file.path(ws, "build")
dep_dir    <- file.path(ws, "dependency")

dir.create(app_dir, recursive = TRUE, showWarnings = FALSE)

# ---- version ----------------------------------------------------------
# APP_VERSION is the workflow tag (e.g. "v0.1.0"), but a manual
# workflow_dispatch run sets it to the branch name ("main"), which is NOT a
# version. Only accept a real version; otherwise fall back to DESCRIPTION.
app_version <- sub("^v", "", Sys.getenv("APP_VERSION", unset = ""))
if (!grepl("^[0-9]+(\\.[0-9]+)*$", app_version)) app_version <- ""
if (!nzchar(app_version)) {
  desc <- file.path(ws, "DESCRIPTION")
  app_version <- if (file.exists(desc)) {
    as.character(read.dcf(desc, fields = "Version")[[1]])
  } else "0.0.0"
}

# ---- owner/repo (for the electron-updater) ----------------------------
repo <- Sys.getenv("GITHUB_REPOSITORY", unset = "YOUR_GITHUB_USER/scConvertShiny")
owner <- sub("/.*$", "", repo)
repo_name <- sub("^.*/", "", repo)

# ---- 1. Shiny entry point --------------------------------------------
# shinyelectron runs shiny::runApp() itself; app.R must only RETURN the app
# object. sc_app() builds it and raises the upload limit (default 20 GB).
app_code <- '
library(scConvertShiny)
options(shiny.launch.browser = FALSE)
options(shiny.deprecation.messages = FALSE)
sc_app()
'
writeLines(app_code, file.path(app_dir, "app.R"))

# ---- 2. dependency discovery -----------------------------------------
find_dep <- function(pattern) {
  hits <- list.files(dep_dir, pattern = pattern, full.names = TRUE)
  if (length(hits) == 0) return(character(0))
  normalizePath(hits, winslash = "/", mustWork = FALSE)
}
local_app <- find_dep("^scConvertShiny[-_].*[.]tar[.]gz$")
local_scconvert <- find_dep("^scConvert[-_].*[.]tar[.]gz$")

if (length(local_scconvert) == 0) {
  message(
    "NOTE: no scConvert_*.tar.gz found in dependency/. scConvert is not on ",
    "CRAN, so the bundled runtime cannot install it unless you supply a ",
    "tarball (built with a C toolchain) in dependency/. The app will still ",
    "start, but conversion will be disabled."
  )
}

local_pkgs <- c(local_app, local_scconvert)
local_yaml <- if (length(local_pkgs)) {
  paste0('      - "', local_pkgs, '"', collapse = "\n")
} else {
  "      []"
}

# ---- icons ------------------------------------------------------------
# Windows uses the .ico; macOS uses an .icns (or .png). Prefer .icns on macOS.
icon <- list.files(file.path(ws, "icons", "ico"), pattern = "[.]ico$",
                   full.names = TRUE)
icon <- if (length(icon)) icon[[1]] else NULL
mac_files <- list.files(file.path(ws, "icons", "mac"),
                        pattern = "[.](icns|png)$", full.names = TRUE)
mac_icns <- mac_files[grepl("[.]icns$", mac_files)]
mac_png <- mac_files[grepl("[.]png$", mac_files)]
mac_icon <- if (length(mac_icns)) mac_icns[[1]] else if (length(mac_png)) mac_png[[1]] else NULL
# electron-builder expects an .icns on macOS; pass it as the primary icon there.
if (identical(tolower(Sys.info()[["sysname"]]), "darwin") && !is.null(mac_icon)) {
  icon <- mac_icon
}
icons_yaml <- if (!is.null(mac_icon)) {
  paste0('\nicons:\n  mac: "',
         normalizePath(mac_icon, winslash = "/", mustWork = FALSE), '"\n')
} else {
  ""
}

# ---- 3. _shinyelectron.yml -------------------------------------------
config_code <- paste0('
app:
  version: "', app_version, '"
  slug: "sconvert-shiny"
  log_level: "info"
  description: "Interactive single-cell format conversion powered by scConvert"
  author: "Zhang Yongchao"
  email: "zhangyongchao@nibs.ac.cn"
  homepage: "https://github.com/', owner, '/', repo_name, '"
  copyright: "Copyright (c) 2026 Zhang Yongchao. MIT."

build:
  runtime_strategy: "bundled"

window:
  width: 1400
  height: 900

installer:
  app_id: "com.sconvert.shiny"
  one_click: false
  allow_to_change_installation_directory: true

# No code-signing certificate yet; enable later with CSC_LINK / CSC_KEY_PASSWORD.
signing:
  sign: false

dependencies:
  extra_packages:
    - scConvertShiny
    - Seurat
    - SeuratObject
    - hdf5r
    - crayon
    - shiny
    - shinydashboard
    - DT
    - callr
    - zip
  r:
    local_packages:
', local_yaml, '

updates:
  enabled: true
  provider: "github"
  check_on_startup: true
  auto_download: true      # download new builds in the background
  auto_install: true       # install silently on quit (false = prompt)
  github:
    owner: "', owner, '"
    repo: "', repo_name, '"

optimize:
  r_library: true
  r_runtime: true
', icons_yaml)
writeLines(config_code, file.path(app_dir, "_shinyelectron.yml"))

# ---- 4. HDF5 for scConvert's configure ---------------------------------
# scConvert compiles from source inside the bundled R runtime and its
# configure step needs HDF5. scConvert's own "reuse hdf5r" strategy fails when
# hdf5r was installed as a (prebuilt) binary, so provide HDF5 explicitly and
# export the variables the configure script documents; the child R process
# spawned by export() inherits them.
sysname <- tolower(Sys.info()[["sysname"]])
if (identical(sysname, "darwin")) {
  system("brew install hdf5 pkg-config")            # idempotent
  h5 <- tryCatch(system("brew --prefix hdf5", intern = TRUE),
                 error = function(e) character(0))
  if (length(h5) == 1 && dir.exists(h5)) {
    Sys.setenv(
      PKG_CONFIG_PATH = file.path(h5, "lib", "pkgconfig"),
      HDF5_CFLAGS = paste0("-I", file.path(h5, "include")),
      HDF5_LIBS = paste0("-L", file.path(h5, "lib"), " -lhdf5")
    )
    message("HDF5 provided from Homebrew: ", h5)
  } else {
    warning("Homebrew hdf5 not found; scConvert may fail to configure.")
  }
} else if (identical(sysname, "windows")) {
  # On Windows, Rtools provides the compiler. If hdf5r's bundled HDF5 is not
  # picked up by scConvert's configure, install HDF5 (e.g. conda-forge/vcpkg)
  # and set HDF5_CFLAGS / HDF5_LIBS here.
}

# ---- 5. Build ----------------------------------------------------------
options(timeout = 3600)   # bundled installs pull a lot of packages; be patient

export(
  appdir    = app_dir,
  destdir   = output_dir,
  app_name  = "scConvertShiny",
  icon      = icon,
  run_after = FALSE,
  overwrite = TRUE
)
