# scConvertShiny

一个基于 `shinydashboard` 的单细胞数据格式转换应用，把
[`scConvert`](https://github.com/mianaz/scConvert) 的格式互转能力封装成
三步向导：

1. 选择输入（小文件浏览器上传 / 大文件与目录型数据用本地路径）；
2. 依检测到的格式选择合法目标格式；
3. 后台异步转换并下载结果，同时生成转换报告。

转换经 Seurat 中枢完成，`h5ad <-> h5Seurat` 走 scConvert 的直接 HDF5 路径。

## 支持的格式

| 格式 | 标识 | 类型 | 读 | 写 |
| --- | --- | --- | --- | --- |
| AnnData | `h5ad` | 文件 | ✓ | ✓ |
| Spatial AnnData | `h5ad_spatial` | 文件 | ✓ | ✓ (自动) |
| h5Seurat | `h5seurat` | 文件 | ✓ | ✓ |
| MuData | `h5mu` | 文件 | ✓ | ✓ |
| Loom | `loom` | 文件 | ✓ | ✓ |
| RDS | `rds` | 文件 | ✓ | ✓ |
| Zarr | `zarr` | 目录 | ✓ | ✓ |
| TileDB-SOMA | `soma` | URI | ✓ | ✓ |
| SpatialData | `spatialdata.zarr` | 目录 | ✓ | ✓ |
| SingleCellExperiment | `sce` | 内存 | — | ✓ (存为 `.sce.rds`) |
| Stereo-seq GEF | `gef` / `cellbin.gef` | 文件 | ✓ | — |

额外只读支持：NanoString CosMx 目录（`cosmx`）。
完整矩阵可在应用的“格式矩阵”页查看（`sc_format_matrix()`）。

目标格式下拉框会随输入自动调整：

- **排除与输入相同的格式**（不做原地转换）；
- 未安装 `SingleCellExperiment` 时隐藏 `sce`，未安装 `tiledbsoma` 时隐藏
  `soma`；
- 其余可写格式对任意可识别输入都开放（scConvert 以 Seurat 为中枢，任意
  源→目标均合法）。

### Assay 名称

`Assay 名称` 是可自动探测的下拉框：h5Seurat 列出 `/assays` 下的 assay，MuData
列出 `/mod` 模态（`rna`→`RNA`、`prot`→`ADT`）；其他格式给出合理默认（一般为
`RNA`，Stereo-seq GEF 为 `Spatial`、CosMx 为 `Nanostring`）。仍可直接输入自定义
名称。相关接口：`sc_detect_assays(path, source_id)`。

## 安装

```r
# remotes::install_github("<your-fork>/scConvertShiny") 或本地安装
install.packages("scConvertShiny", repos = NULL, type = "source")
```

`scConvert` 是可选的运行时依赖：未安装时应用仍可启动，但转换按钮会被禁用。
安装 `scConvert` 需要 C 工具链（Windows: Rtools；Linux: build-essential；
macOS: Xcode CLT），详见 `inst/install/INSTALL_PREREQUISITES.md`：

```r
source(system.file("install", "install_scConvert.R", package = "scConvertShiny"))
source(system.file("install", "verify_scConvert.R", package = "scConvertShiny"))
```

## 内置示例数据

输入步骤提供“示例数据”选项，一键加载 scConvert 仓库自带的演示文件：

| 示例 | 格式 | 来源 |
| --- | --- | --- |
| PBMC 500 cells | AnnData `h5ad` | `inst/extdata/pbmc_demo.h5ad` |
| Visium mouse brain | Spatial AnnData | `inst/extdata/spatial_demo.h5ad` |
| PBMC 500 cells | h5Seurat | `inst/extdata/pbmc_demo.h5seurat` |
| PBMC 500 cells | Loom | `inst/extdata/pbmc_demo.loom` |
| CITE-seq | MuData `h5mu` | `inst/extdata/citeseq_demo.h5mu` |
| PBMC 500 cells | RDS | `inst/extdata/pbmc_demo.rds` |
| Zarr | Zarr | 由 `pbmc_demo.h5ad` 经 scConvert 生成 |

- 已安装 scConvert 时优先使用其内置副本（`system.file()`），无需联网；
- 未安装时从 GitHub raw 下载对应文件（首次需联网，0.6–3.2 MB）；
- Zarr 没有现成文件，由 `pbmc_demo.h5ad` 派生。

编程接口：`sc_demo_data()` 列出示例，`sc_demo_prepare("pbmc_small_h5ad")`
将其准备到本地并返回路径。

## 在 RStudio 中以项目方式打开

包根目录已包含 `scConvertShiny.Rproj`：

1. RStudio → `File` → `Open Project...`，选择 `scConvertShiny.Rproj`；
2. 或直接双击 `scConvertShiny.Rproj` 文件。

若没有 `.Rproj` 文件，用 `File` → `New Project...` → `Existing Directory`，
选到 `scConvertShiny` 文件夹后点 `Create Project`，RStudio 会自动生成。

打开后（Build 面板会自动识别为 R 包）：

- `Build` → `Install and Restart`（或控制台 `devtools::install()`）安装包；
- `devtools::load_all()` 可直接加载开发；
- 然后运行下面的 `run_app()`。

## 运行

```r
library(scConvertShiny)
run_app()
```

## 编程接口

无需启动界面也可复用核心逻辑：

```r
sc_capabilities()                 # 依赖探测
sc_formats()                      # 格式能力矩阵（data.frame）
sc_detect_input("sample.h5ad")    # 输入格式识别
sc_valid_targets_for("h5ad")      # 合法目标格式
sc_convert("sample.h5ad", "h5seurat", "sample.h5Seurat")   # 同步转换
```

## 测试

```r
# 单元测试（testthat）
testthat::test_dir("tests/testthat")

# 或内置自测脚本（不需要 testthat），验证识别/矩阵/异步桩后端全链路
source(system.file("tests", "selftest.R", package = "scConvertShiny"))
```

把 `options(scConvertShiny.backend = "stub")` 设为桩后端后，可在没有
scConvert 的环境里走通整个界面流程。

## 已知限制

- `scConvert` 含 C 源码，从源码安装需要工具链；纯 Web 托管环境若缺少
  `make`/`gcc` 将无法安装。
- 目录型输出（`zarr` / `spatialdata.zarr` / `soma`）下载时自动打包为 zip。
- 浏览器上传默认单文件上限 **20 GB**：`run_app()` 会自动设置
  `shiny.maxRequestSize`；可用 `options(scConvertShiny.maxUploadMB = <MB>)`
  调整，或在 `sc_prepare_input(max_upload_mb = )` 单独指定。超过该值或目录型
  格式请改用本地路径模式。
- `SingleCellExperiment` 目标为内存对象，本应用另存为 `<name>.sce.rds`。

## 许可

MIT。
