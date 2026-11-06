# Map a region of interest onto GLASS sinusoidal tiles

GLASS tiled products use the classic MODIS sinusoidal `h`/`v` grid
(`h<h>v<v>` fragments in file names). These functions rebuild the exact
tile polygons in the sinusoidal projection, transform them to WGS84 and
intersect them with your region of interest, returning the tiles you
need to download.

## Usage

``` r
glass_tiles_for_bbox(lon_min, lat_min, lon_max, lat_max)

glass_tiles_for_sf(roi)
```

## Arguments

- lon_min, lon_max, lat_min, lat_max:

  WGS84 bounding box.

- roi:

  A spatial vector object (`sf`/`sfc`, any CRS).

## Value

An `sf` object (rows = tiles) with columns `h`, `v`, `lon_min`,
`lon_max`, `lat_min`, `lat_max`, `valid` and the tile `geometry` in
WGS84.

## Examples

``` r
glass_tiles_for_bbox(120.8, 30.6, 122.2, 31.9)  # Shanghai
#> Simple feature collection with 1 feature and 7 fields
#> Geometry type: POLYGON
#> Dimension:     XY
#> Bounding box:  xmin: 115.4701 ymin: 30 xmax: 143.5948 ymax: 40
#> Geodetic CRS:  WGS 84
#>    h v  lon_min  lon_max lat_min lat_max valid                       geometry
#> 1 28 5 115.4701 143.5948      30      40  TRUE POLYGON ((130.5407 40, 143....
```
