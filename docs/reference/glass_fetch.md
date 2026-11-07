# Fetch GLASS granules for a variant, ROI and date range in one call

`glass_fetch()` orchestrates the full pipeline of the legacy scripts:
registry variant -\>
[`glass_tiles_for_sf()`](https://gisersqdai.top/glass.sqdaitools/reference/glass_tiles_for_bbox.md)
(or explicit `tiles`) -\>
[`glass_doys()`](https://gisersqdai.top/glass.sqdaitools/reference/glass_doys.md)
-\>
[`glass_list_files()`](https://gisersqdai.top/glass.sqdaitools/reference/glass_list_files.md)
per composite folder -\>
[`glass_download()`](https://gisersqdai.top/glass.sqdaitools/reference/glass_download.md).

## Usage

``` r
glass_fetch(
  variant_id,
  from,
  to,
  roi = NULL,
  tiles = NULL,
  doys_mode = c("span", "start"),
  out_dir,
  dry_run = FALSE,
  delay = 1,
  overwrite = FALSE,
  quiet = FALSE
)
```

## Arguments

- variant_id:

  Registry variant key.

- from, to:

  Date range ("YYYY-mm-dd" or Date).

- roi:

  Optional spatial selection (`sf`/`sfc`). Mutually exclusive with
  `tiles`.

- tiles:

  Optional explicit tile ids, e.g. `c("h28v05")` or
  `c("h27v05", "h28v05")`.

- doys_mode:

  DOY selection mode passed to
  [`glass_doys()`](https://gisersqdai.top/glass.sqdaitools/reference/glass_doys.md)
  (`"span"` keeps every composite overlapping the range; `"start"` keeps
  only those starting inside it).

- out_dir:

  Destination directory.

- dry_run:

  Only return the file manifest without downloading.

- delay, overwrite, quiet:

  Passed to
  [`glass_download()`](https://gisersqdai.top/glass.sqdaitools/reference/glass_download.md).

## Value

A tibble manifest; with download `status` when not a dry run.
