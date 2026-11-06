# Batch download a GLASS file manifest

Downloads every row of a manifest produced by
[`glass_list_files()`](https://giserdaishaoqing.github.io/glass.sqdaitools/reference/glass_list_files.md)
(or any data frame with `filename` and `url` columns) into `out_dir`,
with politeness delays, per-file status tracking, and a
`glass_manifest.csv` ledger written to `out_dir`.

## Usage

``` r
glass_download(manifest, out_dir, delay = 1, overwrite = FALSE, quiet = FALSE)
```

## Arguments

- manifest:

  Data frame with at least `filename` and `url` columns, as returned by
  [`glass_list_files()`](https://giserdaishaoqing.github.io/glass.sqdaitools/reference/glass_list_files.md).

- out_dir:

  Destination directory; created if missing.

- delay:

  Seconds to wait between requests (be nice to the server).

- overwrite:

  Re-download existing valid files.

- quiet:

  Suppress per-file console messages.

## Value

The manifest augmented with `destfile`, `status` and `size_bytes`
columns (also written to `out_dir/glass_manifest.csv`).
