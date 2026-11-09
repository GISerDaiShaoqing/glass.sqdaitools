# GLASS product registry

A curated registry of the GLASS product archive (glass.hku.hk/archive/),
one row per archive variant (product x source x resolution). It stores
the archive URL layout, the observed year coverage, and—for the variants
whose sample files have been checked—file-name fragments and band
scaling metadata used by
[`glass_read()`](https://gisersqdai.top/glass.sqdaitools/reference/glass_read.md).

## Usage

``` r
data(glass_products)
```

## Format

A tibble with one row per archive variant:

- product:

  Product directory under /archive/, e.g. "LAI"

- long_name:

  Human-readable product name

- variant_id:

  Unique key, e.g. "LAI_MODIS_250M"

- source:

  Source/series sub-directory, e.g. "MODIS", "AVHRR"

- res:

  Resolution sub-directory, e.g. "250M"; `NA` if absent

- layout:

  Archive layout: "year_doy" (year/composite folders), "flat" (static
  file collection), "year_files" (granules directly under year folders,
  e.g. AVHRR CMG) or "year_yyyddd" (daily YYYYDDD folders, e.g. AWGF
  LST)

- observed_years:

  Year coverage observed in the directory tree, e.g. "2000-2025"

- start_year, end_year:

  First/last observed year, `NA` if unobserved

- cadence_days:

  Days per synthesis cycle, e.g. 8 for the 8-day products

- temporal_res:

  Temporal resolution label, e.g. "8 days", "daily"

- version:

  Product version fragment of the file names, e.g. "V60"

- code:

  GLASS dataset code fragment, e.g. "GLASS01D01"

- layer:

  Layer name suffix in file names, e.g. "LAI"; `NA` when files carry no
  suffix

- fill_value:

  Fill value of the raw storage, e.g. 255

- scale_factor:

  Scale factor applied to raw values, e.g. 0.01

- valid_min, valid_max:

  Valid data range after scaling

- verified:

  `TRUE` for variants where naming and band metadata were validated
  against a real granule

- url_root:

  Base URL of the variant, i.e. /archive/product/source/res/

- notes:

  Free-text notes

## Details

Built by `data-raw/build_registry.R` from an archive directory scan
(`data-raw/archive_scan.csv`) plus hand verification against sample HDF
granules.
