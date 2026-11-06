# Download one GLASS file with resume support

Low-level httr2 wrapper. A HEAD size check is compared against the local
file, partial downloads (`.part`) are continued with an HTTP `Range`
request, and finished data are renamed into place so a crash never
leaves a truncated file masquerading as complete.

## Usage

``` r
glass_download_file(
  url,
  destfile,
  overwrite = FALSE,
  retries = 3,
  timeout_s = 300
)
```

## Arguments

- url:

  Direct file URL.

- destfile:

  Final local path.

- overwrite:

  If `TRUE`, a valid-looking local file is re-downloaded.

- retries:

  Passed to
  [`httr2::req_retry`](https://httr2.r-lib.org/reference/req_retry.html).

- timeout_s:

  Per-request timeout in seconds.

## Value

One of `"downloaded"`, `"resumed"`, `"resumed_partial"`, `"skipped"` or
`"failed"`; for `"failed"` the error message is kept as attribute
`error`.
