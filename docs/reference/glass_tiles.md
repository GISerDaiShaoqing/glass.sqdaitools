# GLASS sinusoidal tile lookup table

The global 36 x 18 ordered grid used by tiled GLASS products (equivalent
to the MODIS sinusoidal tile system). Each row holds the WGS84
geographic bounding box of one tile; tiles outside the projection
footprint carry `NA` bounds and `valid = FALSE`.

`h` is the horizontal tile index (0-35, west to east) and `v` is the
vertical index (0-17, north to south). Tiles are referenced in file
names and archive paths as `h<h>v<v>`, e.g. `h28v05`.

The source table was produced by projecting the bounding rectangles of
the sinusoidal tiles (`+proj=sinu` with sphere radius 6371007.181, tile
width and height 1111950.51966667 m) to WGS84; see the original
`glass_tiles.tsv` in `data-raw/`. Bounds are those of the curved tile
polygons, so a strict bounding-box intersection test may slightly
over-select corner tiles. Use
[`glass_tiles_for_bbox()`](https://gisersqdai.top/glass.sqdaitools/reference/glass_tiles_for_bbox.md)
or
[`glass_tiles_for_sf()`](https://gisersqdai.top/glass.sqdaitools/reference/glass_tiles_for_bbox.md)
for exact selection.

## Usage

``` r
glass_tiles
```

## Format

A tibble with 648 rows and 7 columns:

- h:

  Horizontal tile index \\0-35\\

- v:

  Vertical tile index \\0-17\\

- lon_min, lon_max, lat_min, lat_max:

  WGS84 bounds of the tile; `NA` if not covered by the projection

- valid:

  `TRUE` when the tile lies inside the sinusoidal footprint
