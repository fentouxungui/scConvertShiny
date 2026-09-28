# shinydashboard server logic.

sc_app_server <- function(input, output, session) {
  rv <- shiny::reactiveValues(
    job = NULL, running = FALSE, result = NULL, report = NULL,
    started = NULL, source = NULL, source_id = NULL, source_label = NULL,
    target_id = NULL, dest = NULL, cleanup = character(0),
    demo_path = NULL, demo_id = NULL, demo_cleanup = character(0),
    demo_msg = NULL
  )

  # Non-reactive copies of the temporary paths. session$onSessionEnded() runs
  # outside a reactive context, so reading rv$cleanup there raises
  # "Can't access reactive value 'cleanup' outside of reactive consumer".
  cleanup_env <- new.env(parent = emptyenv())
  cleanup_env$input <- character(0)
  cleanup_env$demo <- character(0)

  shiny::observe({
    d <- sc_demo_data()
    shiny::updateSelectInput(session, "demo_id",
      choices = stats::setNames(d$id, d$label))
  })

  output$matrix_tbl <- DT::renderDT({
    DT::datatable(
      sc_format_matrix(),
      options = list(pageLength = 15, scrollX = TRUE),
      rownames = FALSE
    )
  })

  output$about_ui <- shiny::renderUI({
    caps <- sc_capabilities()
    ver <- if (is.na(caps$scConvertVersion)) "not installed" else caps$scConvertVersion
    shiny::HTML(paste0(
      "<p>This app wraps the format-conversion capabilities of <code>scConvert</code> in a wizard-style interface.</p>",
      "<p><b>Current environment</b><br>",
      "Backend: <code>", caps$backend, "</code><br>",
      "scConvert: ", ver, "<br>",
      "Seurat: ", caps$Seurat, " &nbsp; SingleCellExperiment: ", caps$SingleCellExperiment,
      "</p>",
      "<p><b>Installing scConvert</b> (requires a C toolchain: Rtools on Windows, build-essential on Linux)<br>",
      "<code>source(system.file('install','install_scConvert.R', package='scConvertShiny'))</code><br>",
      "Verify: <code>source(system.file('install','verify_scConvert.R', package='scConvertShiny'))</code></p>",
      "<p><b>Notes</b>: conversions route through the Seurat hub; h5ad &lt;-&gt; h5Seurat uses a direct HDF5 path for speed. ",
      "Directory outputs (zarr / spatialdata / soma) are zipped automatically on download.</p>"
    ))
  })

  detected <- shiny::reactive({
    if (identical(input$input_mode, "upload")) {
      f <- input$upload_file
      if (is.null(f)) return(NULL)
      d <- sc_detect_input(f$name, check_exists = FALSE)
      if (!is.null(d)) {
        d$path <- f$datapath
        d$exists <- TRUE
      }
      d
    } else if (identical(input$input_mode, "demo")) {
      id <- input$demo_id
      if (is.null(id) || !nzchar(id)) return(NULL)
      d <- sc_demo_data()
      row <- d[match(id, d$id), , drop = FALSE]
      if (nrow(row) == 0) return(NULL)
      f <- sc_format_by_id(row$format_id[1])
      list(
        path = paste0("demo:", id), id = row$format_id[1], label = row$label[1],
        kind = if (nrow(f)) f$kind[1] else NA_character_,
        can_read = TRUE, recognized = TRUE, exists = TRUE, demo_id = id
      )
    } else {
      p <- trimws(input$path_input %||% "")
      if (!nzchar(p)) return(NULL)
      sc_detect_input(p)
    }
  })

  output$detected_ui <- shiny::renderUI({
    caps <- sc_capabilities()
    d <- detected()
    msgs <- list()
    if (!sc_backend_ready(caps)) {
      msgs <- c(msgs, list(shiny::div(
        class = "alert alert-warning",
        if (identical(caps$backend, "stub")) {
          "Stub backend active (for interface testing only)."
        } else {
          "scConvert not detected: you can view the format matrix but cannot run real conversions. See 'About / Install' for setup."
        }
      )))
    }
    if (is.null(d)) {
      msgs <- c(msgs, list(shiny::helpText("Waiting for input...")))
    } else if (!isTRUE(d$recognized)) {
      msgs <- c(msgs, list(shiny::div(
        class = "alert alert-danger",
        paste0("Unrecognized format: ", basename(d$path))
      )))
    } else if (isFALSE(d$exists)) {
      msgs <- c(msgs, list(shiny::div(class = "alert alert-danger", "Path does not exist.")))
    } else {
      msgs <- c(msgs, list(shiny::div(
        class = "alert alert-success",
        paste0("Detected: ", d$label, " (id: ", d$id, ", kind: ", d$kind, ")")
      )))
      if (!is.null(d$demo_id)) {
        ready <- !is.null(rv$demo_path) && identical(rv$demo_id, d$demo_id)
        msgs <- c(msgs, list(shiny::helpText(
          if (ready) {
            paste0("Demo ready: ", rv$demo_path)
          } else {
            "Click 'Load demo data' to download/generate it, or click 'Start conversion' directly."
          }
        )))
      }
      if (!is.null(rv$demo_msg) && !is.null(d$demo_id)) {
        msgs <- c(msgs, list(shiny::helpText(rv$demo_msg)))
      }
    }
    shiny::tagList(msgs)
  })

  shiny::observe({
    d <- detected()
    if (is.null(d) || !isTRUE(d$recognized)) {
      shiny::updateSelectInput(session, "target", choices = character(0))
      return()
    }
    ids <- sc_valid_targets_for(d$id, sc_capabilities())
    f <- sc_formats()
    choices <- stats::setNames(ids, f$label[match(ids, f$id)])
    shiny::updateSelectInput(session, "target", choices = choices)
  })

  assay_info <- shiny::reactive({
    d <- detected()
    if (is.null(d)) return(list(assays = character(0), default = "RNA", source = "format"))
    p <- if (identical(input$input_mode, "demo")) rv$demo_path else d$path
    sc_detect_assays(p, d$id, sc_capabilities())
  })

  output$assay_ui <- shiny::renderUI({
    info <- assay_info()
    shiny::tagList(
      shiny::selectizeInput(
        "assay", "Assay name",
        choices = unique(c(info$default, info$assays)),
        selected = info$default,
        options = list(create = TRUE, placeholder = info$default)
      ),
      if (identical(info$source, "detected") && length(info$assays) > 1) {
        shiny::helpText(paste0("Detected assays: ", paste(info$assays, collapse = ", ")))
      }
    )
  })

  output$convert_btn_ui <- shiny::renderUI({
    if (isTRUE(rv$running)) {
      shiny::actionButton(
        "convert", "Converting...", class = "btn-primary", disabled = TRUE,
        icon = shiny::icon("spinner", class = "fa-spin")
      )
    } else {
      shiny::actionButton(
        "convert", "Start conversion", class = "btn-primary",
        icon = shiny::icon("play")
      )
    }
  })

  output$status_ui <- shiny::renderUI({
    if (isTRUE(rv$running)) {
      shiny::div(
        shiny::strong(shiny::icon("spinner", class = "fa-spin"),
                      " Converting, please wait..."), shiny::br(),
        shiny::em("Large files may take several minutes; keep this page open.")
      )
    } else if (!is.null(rv$result)) {
      if (isTRUE(rv$result$ok)) {
        shiny::div(class = "alert alert-success", "Conversion complete; you can download the result.")
      } else {
        shiny::div(class = "alert alert-danger",
                   paste0("Conversion failed: ", rv$result$message))
      }
    } else {
      shiny::helpText("Conversion has not started yet.")
    }
  })

  output$log_output <- shiny::renderText({
    if (!is.null(rv$result) && nzchar(rv$result$log %||% "")) rv$result$log else ""
  })

  output$report_ui <- shiny::renderUI({
    if (is.null(rv$report)) {
      shiny::helpText("The report appears after conversion.")
    } else {
      shiny::verbatimTextOutput("report_text")
    }
  })
  output$report_text <- shiny::renderText({ rv$report %||% "" })

  shiny::observeEvent(input$load_demo, {
    caps <- sc_capabilities()
    id <- input$demo_id
    if (is.null(id) || !nzchar(id)) return()
    res <- tryCatch(
      shiny::withProgress(message = "Preparing demo data...", value = 0.2, {
        p <- sc_demo_prepare(id, caps = caps)
        shiny::incProgress(0.8)
        p
      }),
      error = function(e) {
        rv$demo_path <- NULL
        rv$demo_msg <- conditionMessage(e)
        NULL
      }
    )
    if (is.null(res)) return()
    rv$demo_path <- res$path
    rv$demo_id <- id
    rv$demo_cleanup <- res$cleanup
    cleanup_env$demo <- res$cleanup
    rv$demo_msg <- paste0("Demo ready: ", res$path)
  })

  shiny::observeEvent(input$convert, {
    if (isTRUE(rv$running)) return()
    caps <- sc_capabilities()
    d <- detected()
    shiny::req(d, isTRUE(d$recognized))

    if (isFALSE(d$exists)) {
      rv$report <- sc_build_report(list(ok = FALSE, message = "path does not exist", source = d$path))
      return()
    }
    target <- input$target
    if (is.null(target) || !nzchar(target)) return()
    if (!sc_backend_ready(caps)) {
      rv$report <- sc_build_report(list(
        ok = FALSE, source = d$path,
        message = "Backend unavailable (scConvert is not installed). Install scConvert first."
      ))
      return()
    }

    prep <- tryCatch(
      if (identical(input$input_mode, "upload")) {
        sc_prepare_input(upload = input$upload_file$datapath,
                         upload_name = input$upload_file$name)
      } else if (identical(input$input_mode, "demo")) {
        id <- input$demo_id
        if (!is.null(rv$demo_path) && identical(rv$demo_id, id)) {
          list(path = rv$demo_path, origin = "demo", cleanup = character(0))
        } else {
          p <- shiny::withProgress(message = "Preparing demo data...", value = 0.2, {
            r <- sc_demo_prepare(id, caps = caps)
            shiny::incProgress(0.8)
            r
          })
          rv$demo_path <- p$path
          rv$demo_id <- id
          rv$demo_cleanup <- p$cleanup
          cleanup_env$demo <- p$cleanup
          rv$demo_msg <- paste0("Demo ready: ", p$path)
          list(path = p$path, origin = "demo", cleanup = character(0))
        }
      } else {
        sc_prepare_input(path = trimws(input$path_input))
      },
      error = function(e) {
        rv$report <- sc_build_report(list(ok = FALSE, message = conditionMessage(e)))
        NULL
      }
    )
    if (is.null(prep)) return()

    rv$cleanup <- prep$cleanup
    cleanup_env$input <- prep$cleanup
    rv$source <- prep$path
    rv$source_id <- d$id
    rv$source_label <- d$label
    rv$target_id <- target

    f <- sc_formats()
    ext <- f$ext[match(target, f$id)]
    base <- sub("\\.[^.]*$", "", basename(prep$path))
    tag <- gsub("\\..*", "", target)
    rv$dest <- file.path(tempdir(), paste0(base, "_", tag, ext))
    if (dir.exists(rv$dest)) unlink(rv$dest, recursive = TRUE)

    assay <- trimws(input$assay %||% "")
    if (!nzchar(assay)) assay <- "RNA"

    rv$started <- Sys.time()
    rv$result <- NULL
    rv$report <- NULL
    rv$running <- TRUE
    rv$job <- sc_run_conversion_async(
      source = rv$source, target_id = rv$target_id, dest_path = rv$dest,
      assay = assay, standardize = isTRUE(input$standardize),
      source_id = rv$source_id, backend = caps$backend
    )
  })

  shiny::observe({
    if (!isTRUE(rv$running) || is.null(rv$job)) return()
    shiny::invalidateLater(500)
    res <- sc_poll_conversion(rv$job)
    if (!isTRUE(res$done)) return()

    rv$running <- FALSE
    rv$result <- res
    f <- sc_formats()
    rv$report <- sc_build_report(list(
      ok = isTRUE(res$ok), message = res$message, log = res$log,
      source = rv$source, source_label = rv$source_label, source_id = rv$source_id,
      target_id = rv$target_id, target_label = f$label[match(rv$target_id, f$id)],
      assay = input$assay, backend = sc_capabilities()$backend,
      elapsed = as.numeric(difftime(Sys.time(), rv$started, units = "secs")),
      dest = rv$dest, output_size = sc_format_size(rv$dest)
    ))
  })

  output$download_ui <- shiny::renderUI({
    if (!is.null(rv$result) && isTRUE(rv$result$ok)) {
      shiny::downloadButton("download", "Download result", class = "btn-primary")
    }
  })

  output$download <- shiny::downloadHandler(
    filename = function() {
      if (is.null(rv$dest)) return("result")
      if (dir.exists(rv$dest)) paste0(basename(rv$dest), ".zip") else basename(rv$dest)
    },
    content = function(file) {
      shiny::req(rv$dest)
      src <- rv$dest
      if (dir.exists(src)) src <- sc_package_output(src)
      file.copy(src, file, overwrite = TRUE)
    }
  )

  session$onSessionEnded(function() {
    paths <- c(cleanup_env$input, cleanup_env$demo)
    if (length(paths)) unlink(paths, recursive = TRUE)
  })
}
