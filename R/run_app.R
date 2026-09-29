# Application launcher.

#' Build the scConvertShiny Shiny application object
#'
#' Returns the [shiny::shinyApp()] object without running it. Useful for
#' embedding (e.g. shinyelectron desktop builds) and for testing.
#'
#' @return A `shiny.appobj`.
#' @export
sc_app <- function() {
  # Shiny caps request bodies at 5 MB by default; raise it to the configured
  # upload limit (default 20 GB).
  options(shiny.maxRequestSize = sc_max_upload_bytes())
  shiny::shinyApp(ui = sc_app_ui, server = sc_app_server)
}

#' Run the scConvertShiny Shiny application
#'
#' @param launch.browser Open the app in the default browser.
#' @param ... Passed on to [shiny::runApp()].
#' @return The value returned by [shiny::runApp()], invisibly.
#' @export
run_app <- function(launch.browser = TRUE, ...) {
  # Shiny caps request bodies at 5 MB by default; raise it to the configured
  # upload limit (default 20 GB) for the duration of the app.
  old <- options(shiny.maxRequestSize = sc_max_upload_bytes())
  on.exit(options(old), add = TRUE)
  shiny::runApp(sc_app(), launch.browser = launch.browser, ...)
}
