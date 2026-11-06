# Getting started with glass.sqdaitools

``` r
library(glass.sqdaitools)
```

This vignette walks through the GLASS data lifecycle covered by the
package: registry lookups, tile mapping, DOY folders, downloading and
post-processing. Dataset-bound chunks run offline; anything that touches
the network is shown with `eval = FALSE` so the vignette builds without
connectivity.

## The product registry

The registry has one row per archive variant (product x source x
resolution) observed under <https://glass.hku.hk/archive/>:

``` r
glass_registry(verified_only = TRUE)[, c("variant_id", "res", "cadence_days",
                                         "observed_years", "url_root")]
#>          variant_id  res cadence_days observed_years
#> 42   EVI_MODIS_250M 250M            8      2000-2025
#> 58   FVC_MODIS_500M 500M            8      2000-2024
#> 106  LAI_MODIS_250M 250M            8      2000-2025
#> 119 NDVI_MODIS_250M 250M            8      2000-2025
#> 131        Ta_MODIS <NA>            1      2000-2020
#>                                          url_root
#> 42   https://glass.hku.hk/archive/EVI/MODIS/250M/
#> 58   https://glass.hku.hk/archive/FVC/MODIS/500M/
#> 106  https://glass.hku.hk/archive/LAI/MODIS/250M/
#> 119 https://glass.hku.hk/archive/NDVI/MODIS/250M/
#> 131        https://glass.hku.hk/archive/Ta/MODIS/
```

Variants with `verified = TRUE` were checked against real granules: file
naming fragments (`code`, `version`, `layer`), year coverage, and band
metadata (`fill_value`, `scale_factor`, `valid_min/valid_max`) all come
from that check and are consumed by
[`glass_read()`](https://giserdaishaoqing.github.io/glass.sqdaitools/reference/glass_read.md)/[`glass_process()`](https://giserdaishaoqing.github.io/glass.sqdaitools/reference/glass_process.md).

## From region of interest to tiles

Tiled GLASS products reuse the MODIS sinusoidal `h<v>` grid. Rebuild the
exact tile polygons and see which ones your study area needs:

``` r
# 一个 2-3 km 缓冲的点(上海人民广场周边)
roi <- sf::st_buffer(
  sf::st_sfc(sf::st_point(c(121.47, 31.23)), crs = 4326),
  3000
)
tiles <- glass_tiles_for_sf(roi)
tiles[, c("h", "v", "lon_min", "lon_max", "lat_min", "lat_max", "valid")]
#> Simple feature collection with 1 feature and 7 fields
#> Geometry type: POLYGON
#> Dimension:     XY
#> Bounding box:  xmin: 115.4701 ymin: 30 xmax: 143.5948 ymax: 40
#> Geodetic CRS:  WGS 84
#>    h v  lon_min  lon_max lat_min lat_max valid                       geometry
#> 1 28 5 115.4701 143.5948      30      40  TRUE POLYGON ((130.5407 40, 143....
```

For straight bounding boxes there is
[`glass_tiles_for_bbox()`](https://giserdaishaoqing.github.io/glass.sqdaitools/reference/glass_tiles_for_bbox.md),
and passing the resulting table directly to
[`glass_fetch()`](https://giserdaishaoqing.github.io/glass.sqdaitools/reference/glass_fetch.md)
is allowed (it understands data frames with `h`/`v` columns).

## Date range to composite folders

The archive stores one folder per composite start day-of-year:

``` r
glass_doys("LAI_MODIS_250M", from = "2018-08-01", to = "2018-08-31")
#> # A tibble: 5 × 4
#>    year   doy date       folder
#>   <int> <int> <date>     <chr> 
#> 1  2018   209 2018-07-28 209   
#> 2  2018   217 2018-08-05 217   
#> 3  2018   225 2018-08-13 225   
#> 4  2018   233 2018-08-21 233   
#> 5  2018   241 2018-08-29 241
```

`mode = "span"` (default) keeps composites partially overlapping the
range; `mode = "start"` keeps only those starting inside it.

## Finding and downloading files

[`glass_list_files()`](https://giserdaishaoqing.github.io/glass.sqdaitools/reference/glass_list_files.md)
reads one composite folder’s listing;
[`glass_fetch()`](https://giserdaishaoqing.github.io/glass.sqdaitools/reference/glass_fetch.md)
loops it over the DOY table and downloads with resume/verification:

``` r
files <- glass_fetch(
  "LAI_MODIS_250M",
  from = "2018-08-01", to = "2018-12-31",
  roi = roi,
  out_dir = "data/glass/lai"
)
# 用 dry_run = TRUE 先看清单,不下载
```

The download engine compares sizes with the server, resumes `.part`
files via HTTP `Range`, and writes `glass_manifest.csv` into `out_dir`,
so an interrupted run continues where it stopped.

## Post-processing

[`glass_process()`](https://giserdaishaoqing.github.io/glass.sqdaitools/reference/glass_process.md)
is the parameterised pipeline: cleanup, mosaic, reproject, mask,
optional temporal collapse:

``` r
mean_lai <- glass_process(
  files,
  roi = roi,
  product = "LAI_MODIS_250M",
  method = "cubic",
  fun = "mean",
  outfile = "glass_lai_mean.tif"
)
```

Band cleanup comes from the registry: the raw fill (e.g. 255) maps to
`NA` after scaling, and the valid scaled range is excluded from
analysis. For an already-read `SpatRaster`,
[`glass_read()`](https://giserdaishaoqing.github.io/glass.sqdaitools/reference/glass_read.md)
with no `product` is a no-op except for explicit `fill`/`valid_range`
arguments.

## Interactive UI

``` r
glass_app()
```

Draw the ROI on a map, pick a verified variant, preview the manifest and
download — the same package functions underneath.
