# shinydashboard user interface.

sc_app_ui <- function(request) {
  shinydashboard::dashboardPage(
    skin = "blue",
    shinydashboard::dashboardHeader(title = "scConvertShiny"),
    shinydashboard::dashboardSidebar(
      shinydashboard::sidebarMenu(
        shinydashboard::menuItem("Convert", tabName = "convert",
                                 icon = shiny::icon("right-left")),
        shinydashboard::menuItem("Format matrix", tabName = "matrix",
                                 icon = shiny::icon("table")),
        shinydashboard::menuItem("About / Install", tabName = "about",
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
              title = "1. Choose input",
              shiny::radioButtons(
                "input_mode", NULL,
                choices = c("Small file upload" = "upload",
                            "Local path (large files / directories)" = "path",
                            "Demo data" = "demo"),
                inline = TRUE
              ),
              shiny::conditionalPanel(
                condition = "input.input_mode == 'upload'",
                shiny::fileInput("upload_file", "Choose a file", multiple = FALSE),
                shiny::helpText(
                  "Browser upload accepts a single file up to 20 GB (adjust with ",
                  "options(scConvertShiny.maxUploadMB = ...)); for very large files ",
                  "or directory formats, prefer the local-path mode."
                )
              ),
              shiny::conditionalPanel(
                condition = "input.input_mode == 'path'",
                shiny::textInput(
                  "path_input", "Absolute path",
                  placeholder = "D:/data/sample.h5ad  or  D:/atlas.zarr  or  soma://collection/measurement"
                ),
                shiny::helpText("Supports files, .zarr / .spatialdata.zarr directories, and soma:// URIs.")
              ),
              shiny::conditionalPanel(
                condition = "input.input_mode == 'demo'",
                shiny::selectInput("demo_id", "Choose demo data", choices = NULL),
                shiny::actionButton("load_demo", "Load demo data",
                                    icon = shiny::icon("download")),
                shiny::helpText(
                  "Demo data come from the scConvert repository (first use downloads ",
                  "0.6-3.2 MB); if scConvert is installed, its bundled copy is used."
                )
              ),
              shiny::uiOutput("detected_ui")
            )
          ),
          shiny::fluidRow(
            shinydashboard::box(
              width = 12, status = "primary", solidHeader = TRUE,
              title = "2. Choose target format",
              shiny::selectInput("target", "Target format", choices = NULL),
              shiny::uiOutput("assay_ui"),
              shiny::checkboxInput("standardize",
                                   "Standardize metadata column names when writing h5ad", FALSE),
              shiny::uiOutput("convert_btn_ui")
            )
          ),
          shiny::fluidRow(
            shinydashboard::box(
              width = 12, status = "primary", solidHeader = TRUE,
              title = "3. Convert & download",
              shiny::uiOutput("status_ui"),
              shiny::uiOutput("download_ui"),
              shiny::verbatimTextOutput("log_output"),
              shiny::hr(),
              shiny::uiOutput("report_ui")
            )
          )
        ),
        shinydashboard::tabItem(
          tabName = "matrix",
          shinydashboard::box(
            width = 12, title = "Format capability matrix", status = "primary",
            solidHeader = TRUE, DT::DTOutput("matrix_tbl")
          )
        ),
        shinydashboard::tabItem(
          tabName = "about",
          shinydashboard::box(
            width = 12, title = "About scConvertShiny", status = "primary",
            solidHeader = TRUE,
            shiny::uiOutput("about_ui")
          )
        )
      )
    )
  )
}
