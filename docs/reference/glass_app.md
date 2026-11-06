# Launch the interactive GLASS download interface

Starts a local 'shiny' app with a 'leaflet' map: draw a region of
interest, pick a verified product variant and date range, preview the
file manifest, then batch-download with
[`glass_fetch()`](https://giserdaishaoqing.github.io/glass.sqdaitools/reference/glass_fetch.md)
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
[`glass_fetch()`](https://giserdaishaoqing.github.io/glass.sqdaitools/reference/glass_fetch.md).
Requires 'shiny', 'leaflet' and 'leafem' (Suggested dependencies) to be
installed.

## Examples

``` r
if (FALSE) { # \dontrun{
glass_app()
} # }
```
