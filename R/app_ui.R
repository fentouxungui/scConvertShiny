# shinydashboard user interface.

sc_app_ui <- function(request) {
  shinydashboard::dashboardPage(
    skin = "blue",
    shinydashboard::dashboardHeader(title = "scConvertShiny"),
    shinydashboard::dashboardSidebar(
      shinydashboard::sidebarMenu(
        shinydashboard::menuItem("格式转换", tabName = "convert",
                                 icon = shiny::icon("right-left")),
        shinydashboard::menuItem("格式矩阵", tabName = "matrix",
                                 icon = shiny::icon("table")),
        shinydashboard::menuItem("关于 / 安装", tabName = "about",
                                 icon = shiny::icon("circle-info"))
      )
    ),
    shinydashboard::dashboardBody(
      shinydashboard::tabItems(
        shinydashboard::tabItem(
          tabName = "convert",
          shiny::fluidRow(
            shinydashboard::box(
              width = 12, status = "primary", solidHeader = TRUE,
              title = "1. 选择输入",
              shiny::radioButtons(
                "input_mode", NULL,
                choices = c("小文件上传" = "upload",
                            "本地路径（大文件 / 目录）" = "path",
                            "示例数据" = "demo"),
                inline = TRUE
              ),
              shiny::conditionalPanel(
                condition = "input.input_mode == 'upload'",
                shiny::fileInput("upload_file", "选择文件", multiple = FALSE),
                shiny::helpText(
                  "浏览器上传单文件上限 20 GB（可用 ",
                  "options(scConvertShiny.maxUploadMB = ...) 调整）；",
                  "超大文件或目录型格式建议改用本地路径。"
                )
              ),
              shiny::conditionalPanel(
                condition = "input.input_mode == 'path'",
                shiny::textInput(
                  "path_input", "绝对路径",
                  placeholder = "D:/data/sample.h5ad  或  D:/atlas.zarr  或  soma://collection/measurement"
                ),
                shiny::helpText("支持文件、.zarr / .spatialdata.zarr 目录以及 soma:// URI。")
              ),
              shiny::conditionalPanel(
                condition = "input.input_mode == 'demo'",
                shiny::selectInput("demo_id", "选择示例数据", choices = NULL),
                shiny::actionButton("load_demo", "加载示例数据",
                                    icon = shiny::icon("download")),
                shiny::helpText(
                  "示例数据来自 scConvert 仓库（首次使用需联网下载 0.6–3.2 MB）；",
                  "若已安装 scConvert，则直接使用其内置副本。"
                )
              ),
              shiny::uiOutput("detected_ui")
            )
          ),
          shiny::fluidRow(
            shinydashboard::box(
              width = 12, status = "primary", solidHeader = TRUE,
              title = "2. 选择目标格式",
              shiny::selectInput("target", "目标格式", choices = NULL),
              shiny::uiOutput("assay_ui"),
              shiny::checkboxInput("standardize", "转为 h5ad 时标准化元数据列名", FALSE),
              shiny::uiOutput("convert_btn_ui")
            )
          ),
          shiny::fluidRow(
            shinydashboard::box(
              width = 12, status = "primary", solidHeader = TRUE,
              title = "3. 转换与下载",
              shiny::uiOutput("status_ui"),
              shiny::verbatimTextOutput("log_output"),
              shiny::downloadButton("download", "下载结果"),
              shiny::hr(),
              shiny::uiOutput("report_ui")
            )
          )
        ),
        shinydashboard::tabItem(
          tabName = "matrix",
          shinydashboard::box(
            width = 12, title = "格式能力矩阵", status = "primary",
            solidHeader = TRUE, DT::DTOutput("matrix_tbl")
          )
        ),
        shinydashboard::tabItem(
          tabName = "about",
          shinydashboard::box(
            width = 12, title = "关于 scConvertShiny", status = "primary",
            solidHeader = TRUE,
            shiny::uiOutput("about_ui")
          )
        )
      )
    )
  )
}
