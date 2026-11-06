# Convert a date range to composite DOY folders

GLASS composite products are stored in folders keyed by the day-of-year
(DOY) at which a synthesis cycle **starts**, one set per year:
`/archive/<product>/<source>/<res>/<year>/<doy>/`. `glass_doys()`
computes which folders a calendar date range needs, for any cadence held
in the registry.

## Usage

``` r
glass_doys(variant_id, from, to, mode = c("span", "start"))
```

## Arguments

- variant_id:

  Registry variant key, e.g. `"LAI_MODIS_250M"` (used to look up
  `cadence_days`).

- from, to:

  Start/end date as `Date` or `YYYY-mm-dd` string.

- mode:

  How to treat folders that only partially overlap the range: `"span"`
  (default) keeps every composite whose interval intersects
  `[from, to]`; `"start"` keeps only composites starting inside the
  range. The legacy scripts used the equivalent of `"start"`.

## Value

A tibble with columns `year`, `doy` (integer, cycle start), `date`
(start date of that cycle), `folder` (zero-padded `sprintf` folder
name).

## Examples

``` r
glass_doys("LAI_MODIS_250M", "2018-08-01", "2018-12-31")
#> # A tibble: 20 × 4
#>     year   doy date       folder
#>    <int> <int> <date>     <chr> 
#>  1  2018   209 2018-07-28 209   
#>  2  2018   217 2018-08-05 217   
#>  3  2018   225 2018-08-13 225   
#>  4  2018   233 2018-08-21 233   
#>  5  2018   241 2018-08-29 241   
#>  6  2018   249 2018-09-06 249   
#>  7  2018   257 2018-09-14 257   
#>  8  2018   265 2018-09-22 265   
#>  9  2018   273 2018-09-30 273   
#> 10  2018   281 2018-10-08 281   
#> 11  2018   289 2018-10-16 289   
#> 12  2018   297 2018-10-24 297   
#> 13  2018   305 2018-11-01 305   
#> 14  2018   313 2018-11-09 313   
#> 15  2018   321 2018-11-17 321   
#> 16  2018   329 2018-11-25 329   
#> 17  2018   337 2018-12-03 337   
#> 18  2018   345 2018-12-11 345   
#> 19  2018   353 2018-12-19 353   
#> 20  2018   361 2018-12-27 361   
```
