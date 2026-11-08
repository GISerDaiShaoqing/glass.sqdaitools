#' Launch the interactive GLASS download interface
#'
#' Starts a local 'shiny' app with a 'leaflet' map: click twice on the map to
#' frame your region of interest as a rectangle, pick a verified product
#' variant and date range, preview the file manifest, then batch-download
#' with [glass_fetch()] in one click.
#'
#' The app is thin: everything happens through the package functions, so the
#' same workflow is available non-interactively via [glass_fetch()].
#' The download directory can be picked with a native folder dialog (base
#' 'tcltk'; works in local interactive sessions, while headless sessions fall
#' back to typing the path), and a progress bar tracks each file during the
#' batch download.
#' Requires 'shiny' and 'leaflet' (Suggested dependencies) to be installed.
#' Base maps default to an unbiased Esri World Imagery layer; an Amap street
#' layer is optional but uses GCJ-02 coordinates, so it is offset by roughly
#' 500 meters from WGS84.
#'
#' @param port Port for the shiny server (see [shiny::runApp()]).
#'
#' @return Returns invisibly when the app stops.
#'
#' @export
#' @examples
#' \dontrun{
#' glass_app()
#' }
glass_app <- function(port = getOption("shiny.port")) {
  for (pkg in c("shiny", "leaflet")) {
    if (!requireNamespace(pkg, quietly = TRUE)) {
      glass_abort(paste0(
        "glass_app() requires package '", pkg, "'. ",
        "Install it with install.packages('", pkg, "')"
      ))
    }
  }
  app_dir <- system.file("shinyapp", package = "glass.sqdaitools")
  if (!nzchar(app_dir)) glass_abort("shiny app directory not found; reinstall the package")
  shiny::runApp(app_dir, port = port)
}
