# Merge multi-tile GLASS rasters

Tile-aware convenience wrapper over
[`terra::merge()`](https://rspatial.github.io/terra/reference/merge.html):
merges the extent of several tiled granules (from the same sinusoidal
source grid) into a single raster.

## Usage

``` r
glass_mosaic(...)
```

## Arguments

- ...:

  `SpatRaster` objects (each the result of
  [`glass_read()`](https://gisersqdai.top/glass.sqdaitools/reference/glass_read.md)).

## Value

A merged `SpatRaster`.
