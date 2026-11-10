#' Launch the interactive GLASS download interface
#'
#' Starts a local 'shiny' app with a 'leaflet' map: switch between a roam mode
#' (free pan/zoom, no drawing) and a draw mode with a button, then click twice
#' on the map in draw mode to frame your region of interest as a rectangle;
#' pick a verified product variant and date range, preview the file manifest,
#' then batch-download with [glass_fetch()] in one click.
#'
#' The app is thin: everything happens through the package functions, so the
#' same workflow is available non-interactively via [glass_fetch()].
#' The download directory can be picked with the built-in, in-page directory
#' browser (package 'shinyFiles'; no native modal, works in RStudio's Viewer
#' pane and in any browser); without 'shinyFiles' the path can simply be
#' typed in. A progress bar tracks each file during the batch download.
#'
#' After a download, the map-header controls overlay a downsampled preview
#' of the downloaded granules (fill/scale from the registry, multi-tile
#' mosaics, cropped to the ROI and reprojected to EPSG:4326). Previously
#' downloaded data can be brought in without re-downloading with the
#' "Scan Import" button, which opens the same directory browser and
#' recognizes GLASS granules by naming/code; the preview shows the first
#' SDS layer of multi-band products.
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
