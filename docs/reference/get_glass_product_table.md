# Fetch the GLASS product overview table online

Scrapes the product overview table from glass.hku.hk with 'httr2'. On
failure the bundled 25-product fallback table is used. In new code
prefer
[`glass_registry()`](https://gisersqdai.top/glass.sqdaitools/reference/glass_registry.md)/[`glass_product_info()`](https://gisersqdai.top/glass.sqdaitools/reference/glass_registry.md),
which also carry archive paths and band metadata.

## Usage

``` r
get_glass_product_table(use_fallback = TRUE)
```

## Arguments

- use_fallback:

  Logical; if `TRUE` (default) return the bundled fallback table when
  the online scrape fails.

## Value

A data frame of product overview rows, or `NULL`.
