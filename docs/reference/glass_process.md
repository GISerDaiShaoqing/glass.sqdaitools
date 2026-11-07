# Reproject, mask and composite GLASS rasters for a region

Takes granule paths (or an already-read `SpatRaster` stack), applies
[`glass_read()`](https://gisersqdai.top/glass.sqdaitools/reference/glass_read.md)
cleanup, groups granules by composite date, merges tiles per date,
reprojects the result to the CRS of `roi`, crops and masks, and
optionally collapses layers with a function (e.g. a temporal mean). This
is the parameterised version of the legacy `glass_process.R` script.

## Usage

``` r
glass_process(
  input,
  roi,
  target_crs = NULL,
  res = NULL,
  method = "cubic",
  fun = "none",
  outfile = NULL,
  product = NULL,
  ...
)
```

## Arguments

- input:

  Granule paths of one variant, or a `SpatRaster` stack (then fill/scale
  handling is assumed done).

- roi:

  Region of interest (`sf`/`sfc`); its CRS is the target CRS.

- target_crs:

  Optionally override the target CRS.

- res:

  Output resolution in target-CRS units (default: automatic).

- method:

  [`terra::project()`](https://rspatial.github.io/terra/reference/project.html)
  resampling method, e.g. `"cubic"` (default) or `"near"` for
  categorical data.

- fun:

  `"none"` (default) keeps one layer per granule date; `"mean"`,
  `"max"`, `"min"` or a function collapse layers.

- outfile:

  Optional GeoTIFF path to write.

- product:

  Registry variant key for
  [`glass_read()`](https://gisersqdai.top/glass.sqdaitools/reference/glass_read.md).

- ...:

  Passed on to
  [`glass_read()`](https://gisersqdai.top/glass.sqdaitools/reference/glass_read.md).

## Value

A processed `SpatRaster`.

## Examples

``` r
if (FALSE) { # \dontrun{
files <- glass_fetch("LAI_MODIS_250M", "2018-08-01", "2018-12-31",
                     tiles = "h28v05", out_dir = "data/glass/lai")
mean_lai <- glass_process(files, roi = shanghai_sf, outfile = "lai_mean.tif")
} # }
```
