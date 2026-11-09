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
  quiet = FALSE,
  progress = NULL
)
```

## Arguments

- variant_id:

  Registry variant key.

- from, to:

  Date range ("YYYY-mm-dd" or Date). Ignored for static file collections
  (`layout = "flat"`, e.g. AGB, KGClim, Crops): those are whole-file
  exchanges, so the full file list is fetched instead.

- roi:

  Optional spatial selection (`sf`/`sfc`). Mutually exclusive with
  `tiles`. Leave both `roi` and `tiles` unset for global (CMG) variants
  that carry no tiles.

- tiles:

  Optional explicit tile ids, e.g. `c("h28v05")` or
  `c("h27v05", "h28v05")`.

- doys_mode:

  DOY selection mode passed to
  [`glass_doys()`](https://gisersqdai.top/glass.sqdaitools/reference/glass_doys.md)
  (`"span"` keeps every composite overlapping the range; `"start"` keeps
  only those starting inside it). Same semantics in the self-scan
  branch, calibrated against the composite dates found in the year
  folder.

- out_dir:

  Destination directory.

- dry_run:

  Only return the file manifest without downloading.

- delay, overwrite, quiet, progress:

  Passed to
  [`glass_download()`](https://gisersqdai.top/glass.sqdaitools/reference/glass_download.md).

## Value

A tibble manifest; with download `status` when not a dry run.

## Details

Three archive shapes are handled:

- `layout = "flat"` — static whole-file exchanges (AGB, KGClim, Crops,
  Albedo ABI climatologies). The date range is ignored and the full root
  listing is returned.

- cadence known (`cadence_days`): composite DOY folders are computed
  with
  [`glass_doys()`](https://gisersqdai.top/glass.sqdaitools/reference/glass_doys.md)
  and each `<year>/<doy>/` folder is listed.

- cadence unknown (`cadence_days` is NA): self-scan. Each year folder
  intersecting the range is listed once and granules are filtered by
  composite codes parsed from their filenames (`A{yyyy}{ddd}`, month
  codes such as `.2010xx.`, or trailing 7-digit year codes). Single- or
  irregularly spaced composites keep the whole year; regular ones follow
  `doys_mode`. This covers products whose granules sit directly in year
  folders (FVC, Albedo AVHRR/MIX/0.5D, PAR, RN, SM, LST/AVHRR Daily-ODC,
  NDVI/MODIS 0.25°, TPSCE, AWGF LST), roots wrapped one level by a
  version dir (NPP), and year folders holding DOY sub-folders (Albedo
  MODIS 250M).

The self-scan keeps the fetch path tolerant to registry omissions: when
an unmeasured variant turns out to have a different layout than the
skeleton assumption, it still resolves granules from what the archive
itself reports.

## Examples

``` r
if (FALSE) { # \dontrun{
# verified cadence (fast path)
glass_fetch("LAI_MODIS_250M", "2018-08-01", "2018-08-31", tiles = "h28v05")
# cadence unknown (self-scan path)
glass_fetch("FVC_AVHRR_0_5D", "2018-08-01", "2018-09-30", dry_run = TRUE)
} # }
```
