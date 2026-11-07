# List files of a GLASS archive composite folder

Reads the GLASS archive directory listing for one composite folder and
returns the matching data files as a manifest (filename, URL, doy,
tile). The listing is plain HTML with relative links, so no credentials
or API keys are needed.

## Usage

``` r
glass_list_files(
  variant_id,
  year = NULL,
  doy = NULL,
  tiles = NULL,
  ext = "hdf"
)
```

## Arguments

- variant_id:

  Registry variant key, e.g. `"LAI_MODIS_250M"`.

- year:

  Calendar year of the composite (folder level). May be `NULL` for
  "flat" layout variants (e.g. AGB).

- doy:

  Day of year of the composite, integer or `"217"`; `NULL` only allowed
  for "flat" variants.

- tiles:

  Optional tile selector: a character vector like `c("h28v05")` or a
  data frame with `h`/`v` columns (e.g. the output of
  [`glass_tiles_for_bbox()`](https://gisersqdai.top/glass.sqdaitools/reference/glass_tiles_for_bbox.md)).

- ext:

  File extensions to keep, e.g. `c("hdf", "hdf.xml")`; default `"hdf"`
  (the data files).

## Value

A tibble with columns `filename`, `url`, `variant_id`, `year`, `doy`,
`tile`, `ext`.

## Examples

``` r
if (FALSE) { # \dontrun{
glass_list_files("LAI_MODIS_250M", year = 2018, doy = 217, tiles = "h28v05")
} # }
```
