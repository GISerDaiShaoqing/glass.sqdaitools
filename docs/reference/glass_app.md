# Launch the interactive GLASS download interface

Starts a local 'shiny' app with a 'leaflet' map: switch between a roam
mode (free pan/zoom, no drawing) and a draw mode with a button, then
click twice on the map in draw mode to frame your region of interest as
a rectangle; pick a verified product variant and date range, preview the
file manifest, then batch-download with
[`glass_fetch()`](https://gisersqdai.top/glass.sqdaitools/reference/glass_fetch.md)
in one click.

## Usage

``` r
glass_app(port = getOption("shiny.port"))
```

## Arguments

- port:

  Port for the shiny server (see
  [`shiny::runApp()`](https://rdrr.io/pkg/shiny/man/runApp.html)).

## Value

Returns invisibly when the app stops.

## Details

The app is thin: everything happens through the package functions, so
the same workflow is available non-interactively via
[`glass_fetch()`](https://gisersqdai.top/glass.sqdaitools/reference/glass_fetch.md).
The download directory can be picked with the built-in, in-page
directory browser (package 'shinyFiles'; no native modal, works in
RStudio's Viewer pane and in any browser); without 'shinyFiles' the path
can simply be typed in. A progress bar tracks each file during the batch
download. Requires 'shiny' and 'leaflet' (Suggested dependencies) to be
installed. Base maps default to an unbiased Esri World Imagery layer; an
Amap street layer is optional but uses GCJ-02 coordinates, so it is
offset by roughly 500 meters from WGS84.

## Examples

``` r
if (FALSE) { # \dontrun{
glass_app()
} # }
```
