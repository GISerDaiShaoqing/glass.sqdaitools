#' Convert a date range to composite DOY folders
#'
#' GLASS composite products are stored in folders keyed by the day-of-year
#' (DOY) at which a synthesis cycle **starts**, one set per year:
#' `/archive/<product>/<source>/<res>/<year>/<doy>/`. `glass_doys()`
#' computes which folders a calendar date range needs, for any cadence held
#' in the registry.
#'
#' @param variant_id Registry variant key, e.g. `"LAI_MODIS_250M"`
#'   (used to look up `cadence_days`).
#' @param from,to Start/end date as `Date` or `YYYY-mm-dd` string.
#' @param mode How to treat folders that only partially overlap the range:
#'   `"span"` (default) keeps every composite whose interval intersects
#'   `[from, to]`; `"start"` keeps only composites starting inside the
#'   range. The legacy scripts used the equivalent of `"start"`.
#'
#' @return A tibble with columns `year`, `doy` (integer, cycle start),
#'   `date` (start date of that cycle), `folder` (zero-padded `sprintf`
#'   folder name).
#'
#' @export
#' @examples
#' glass_doys("LAI_MODIS_250M", "2018-08-01", "2018-12-31")
glass_doys <- function(variant_id, from, to, mode = c("span", "start")) {
  mode <- match.arg(mode)
  info <- glass_product_info(variant_id = variant_id)
  cadence <- info$cadence_days[[1]]
  if (is.na(cadence)) {
    glass_abort(paste0(
      "cadence unknown for variant '", variant_id,
      "' - it cannot be queried by composite DOY. ",
      "If this is a static file collection (layout \"flat\", e.g. AGB/KGClim), ",
      "call glass_list_files() directly or use glass_fetch(), which skips ",
      "the DOY lookup and returns the full file list."
    ))
  }
  from <- as.Date(from); to <- as.Date(to)
  if (from > to) glass_abort("`from` must not be later than `to`")

  out <- list()
  for (year in seq(as.integer(format(from, "%Y")), as.integer(format(to, "%Y")))) {
    # 每年的合成起始 DOY 序列:1, 1+d, ... (≤365)
    doy_starts <- seq(1L, 365L, by = cadence)
    start_dates <- as.Date(sprintf("%d-01-01", year)) + (doy_starts - 1L)
    next_start <- start_dates + (cadence - 1L)
    keep_i <- switch(mode,
      span = start_dates <= to & next_start >= from,
      start = start_dates >= from & start_dates <= to
    )
    out[[length(out) + 1L]] <- tibble::tibble(
      year = year,
      doy = as.integer(doy_starts[keep_i]),
      date = start_dates[keep_i]
    )
  }
  res <- dplyr::bind_rows(out)
  res$folder <- sprintf("%03d", res$doy)
  res
}
