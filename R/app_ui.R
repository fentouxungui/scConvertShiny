# shinydashboard user interface.

sc_app_ui <- function(request) {
  shinydashboard::dashboardPage(
    skin = "blue",
    shinydashboard::dashboardHeader(
      title = "scConvertShiny",
      shiny::tags$li(
        class = "dropdown",
        shiny::tags$a(
          href = "https://github.com/fentouxungui/scConvertShiny",
          target = "_blank", rel = "noopener",
          title = "scConvertShiny on GitHub",
          shiny::icon("github"), " scConvertShiny"
        )
      ),
      shiny::tags$li(
        class = "dropdown",
        shiny::tags$a(
          href = "https://github.com/mianaz/scConvert",
          target = "_blank", rel = "noopener",
          title = "scConvert on GitHub",
          shiny::icon("github"), " scConvert"
        )
      )
    ),
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
      htmltools::htmlDependency(
        "scConvertShiny-folder-upload", "0.1",
        src = system.file("www", package = "scConvertShiny"),
        script = "folder-upload.js"
      ),
      shiny::tags$head(
        shiny::tags$script(
          src = "https://cdn.jsdelivr.net/npm/jszip@3.10.1/dist/jszip.min.js"
        )
      ),
      shinydashboard::tabItems(
        shinydashboard::tabItem(
          tabName = "convert",
          shiny::fluidRow(
            shinydashboard::box(
              width = 12, status = "primary", solidHeader = TRUE,
              title = "1. Choose input",
              shiny::radioButtons(
                "input_mode", NULL,
                choices = c("Upload file" = "upload",
                            "Upload folder" = "folder",
                            "Demo data" = "demo"),
                inline = TRUE
              ),
              shiny::conditionalPanel(
                condition = "input.input_mode == 'upload'",
                shiny::fileInput("upload_file", "Choose a file", multiple = FALSE),
                shiny::helpText(
                  "A single file up to 20 GB (adjust with ",
                  "options(scConvertShiny.maxUploadMB = ...)). ",
                  "Use this for single-file formats: h5ad, h5Seurat, h5mu, loom, rds."
                )
              ),
              shiny::conditionalPanel(
                condition = "input.input_mode == 'folder'",
                shiny::tags$div(
                  class = "form-group",
                  shiny::tags$label("Choose a folder", `for` = "folder_picker"),
                  shiny::tags$input(id = "folder_picker", type = "file",
                                    webkitdirectory = "", multiple = NA),
                  shiny::tags$div(id = "folder_status", class = "help-block")
                ),
                shiny::fileInput("folder_zip", "...or choose a .zip archive",
                                 accept = ".zip", multiple = FALSE),
                shiny::helpText(
                  "Folder upload is for directory-based data: Zarr (.zarr), ",
                  "SpatialData (.spatialdata.zarr) and NanoString CosMx ",
                  "(a folder of CSV files). Choosing a folder zips it in the ",
                  "browser and the server extracts it automatically; you can ",
                  "also upload a .zip you made yourself."
                )
              ),
              shiny::conditionalPanel(
                condition = "input.input_mode == 'demo'",
                shiny::selectInput("demo_id", "Choose demo data", choices = NULL),
                shiny::actionButton("load_demo", "Load demo data",
                                    icon = shiny::icon("download")),
                shiny::helpText(
                  "Demo data come from the scConvert repository (first use ",
                  "downloads 0.6-3.2 MB); if scConvert is installed, its ",
                  "bundled copy is used."
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
