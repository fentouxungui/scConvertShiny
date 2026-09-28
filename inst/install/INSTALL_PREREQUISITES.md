# scConvert 安装前置条件

`scConvertShiny` 本身是纯 R/Shiny 包，安装不需要编译。但它依赖的
`scConvert` **含有 C 源码**（其 `DESCRIPTION` 声明 `NeedsCompilation: yes`），
因此从源码安装 `scConvert` 需要一台带 C 工具链的机器。

## 结论（重要）

- 仅能安装 `scConvertShiny` 但没有 `scConvert` 时，应用仍可启动：界面会
  显示格式能力矩阵，但转换按钮被禁用并给出提示。
- 要进行真实格式转换，必须先在目标机器装好 `scConvert`。

## 各平台要求

### Windows

1. 安装与本机 R 版本匹配的 Rtools（例如 R 4.5 对应 Rtools45，R 4.4 对应 Rtools44）。
   下载：https://cran.r-project.org/bin/windows/Rtools/
2. 安装时勾选 “Add rtools to system PATH”，或在 R 中运行
   `pkgbuild::has_build_tools(debug = TRUE)` 确认可用。
3. 关键：命令行需能找到 `make` 与 `gcc`。在 Windows 上 `make` 由 Rtools 提供。

### Linux

```sh
sudo apt-get install -y build-essential libhdf5-dev libzstd-dev
```

### macOS

```sh
xcode-select --install
brew install hdf5 zstd
```

## 安装步骤

在 R 中运行随包提供的一键脚本：

```r
source(system.file("install", "install_scConvert.R", package = "scConvertShiny"))
```

或手动：

```r
options(repos = c(CRAN = "https://cloud.r-project.org"))
install.packages("remotes")
remotes::install_github("mianaz/scConvert", upgrade = "never")
```

## 安装后验证

```r
source(system.file("install", "verify_scConvert.R", package = "scConvertShiny"))
```

该脚本会：加载 `scConvert` → 构造一个极小的 Seurat 对象 → 写出 `.h5Seurat`
→ 转成 `.h5ad` → 再转回 `.h5Seurat`，并比对维度，验证整条链路可用。

## 为什么托管运行时里装不上

在 Open-Science 应用托管的 conda R 环境（R 4.5.3）中实测：

- 环境内有 mingw-w64 `gcc 16.2.0`（`Library/bin/x86_64-w64-mingw32-gcc.exe`），
- 但**缺少 `make` 与 `sh`**，且受管安装工具无法补装 conda 的 `m2-make`
  （会被映射为不存在的 `r-m2-make` 而失败），
- 因此 `R CMD INSTALL` 无法执行，`scConvert` 不能在该环境编译安装。

解决办法：在具备上述工具链的机器上安装一次，或获取/构建预编译二进制后
用 `install.packages("<scConvert_x.y.z.zip>", repos = NULL, type = "binary")`
安装。

## 可选：C 命令行加速（非必需）

`scConvert` 附带一个可选的 C 二进制 `scconvert`，用于 HDF5 文件之间的流式
转换（更快、内存恒定）。不构建它也能正常工作，包会自动回退到纯 R 路径。
构建方式见 `scConvert` 仓库的 `src/Makefile.cli`。
