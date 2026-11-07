# Query the GLASS product registry

`glass_registry()` returns the bundled
[glass_products](https://gisersqdai.top/glass.sqdaitools/reference/glass_products.md)
registry, optionally filtered. `glass_product_info()` returns one or a
few rows and errors loudly when the lookup is ambiguous, so it is handy
for interactive use.

## Usage

``` r
glass_registry(product = NULL, variant_id = NULL, verified_only = FALSE)

glass_product_info(variant_id = NULL, product = NULL)
```

## Arguments

- product:

  Product directory name(s) under /archive/, e.g. `"LAI"`. In
  `glass_registry()`, `NULL` keeps all products.

- variant_id:

  Optional exact variant key(s), e.g. `"LAI_MODIS_250M"`.

- verified_only:

  If `TRUE`, return only variants whose file naming and band metadata
  were verified against a sample granule.

## Value

A tibble of registry rows (see
[glass_products](https://gisersqdai.top/glass.sqdaitools/reference/glass_products.md)
for columns).

## Examples

``` r
glass_registry("LAI")
#> # A tibble: 8 × 21
#>   product long_name     variant_id source res   layout observed_years start_year
#>   <chr>   <chr>         <chr>      <chr>  <chr> <chr>  <chr>               <dbl>
#> 1 LAI     Leaf Area In… LAI_AVHRR  AVHRR  NA    year_… 1981-2018            1981
#> 2 LAI     Leaf Area In… LAI_HR_LA… HR_LAI V01   year_… NA                     NA
#> 3 LAI     Leaf Area In… LAI_MODIS… MODIS  0.05D year_… NA                     NA
#> 4 LAI     Leaf Area In… LAI_MODIS… MODIS  0.1D  year_… NA                     NA
#> 5 LAI     Leaf Area In… LAI_MODIS… MODIS  0.25D year_… NA                     NA
#> 6 LAI     Leaf Area In… LAI_MODIS… MODIS  0.5D  year_… NA                     NA
#> 7 LAI     Leaf Area In… LAI_MODIS… MODIS  250M  year_… 2000-2025            2000
#> 8 LAI     Leaf Area In… LAI_MODIS… MODIS  500M  year_… NA                     NA
#> # ℹ 13 more variables: end_year <dbl>, cadence_days <int>, temporal_res <chr>,
#> #   version <chr>, code <chr>, layer <chr>, fill_value <dbl>,
#> #   scale_factor <dbl>, valid_min <dbl>, valid_max <dbl>, verified <lgl>,
#> #   url_root <chr>, notes <chr>
glass_product_info("NDVI_MODIS_250M")
#> # A tibble: 1 × 21
#>   product long_name     variant_id source res   layout observed_years start_year
#>   <chr>   <chr>         <chr>      <chr>  <chr> <chr>  <chr>               <dbl>
#> 1 NDVI    Normalized D… NDVI_MODI… MODIS  250M  year_… 2000-2025            2000
#> # ℹ 13 more variables: end_year <dbl>, cadence_days <int>, temporal_res <chr>,
#> #   version <chr>, code <chr>, layer <chr>, fill_value <dbl>,
#> #   scale_factor <dbl>, valid_min <dbl>, valid_max <dbl>, verified <lgl>,
#> #   url_root <chr>, notes <chr>
```
