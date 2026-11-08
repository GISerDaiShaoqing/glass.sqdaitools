#' Fetch GLASS granules for a variant, ROI and date range in one call
#'
#' `glass_fetch()` orchestrates the full pipeline of the legacy scripts:
#' registry variant -> [glass_tiles_for_sf()] (or explicit `tiles`) ->
#' [glass_doys()] -> [glass_list_files()] per composite folder ->
#' [glass_download()].
#'
#' @param variant_id Registry variant key.
#' @param from,to Date range ("YYYY-mm-dd" or Date).
#' @param roi Optional spatial selection (`sf`/`sfc`). Mutually exclusive
#'   with `tiles`. Leave both `roi` and `tiles` unset for global (CMG)
#'   variants that carry no tiles.
#' @param tiles Optional explicit tile ids, e.g. `c("h28v05")` or
#'   `c("h27v05", "h28v05")`.
#' @param doys_mode DOY selection mode passed to [glass_doys()] (`"span"`
#'   keeps every composite overlapping the range; `"start"` keeps only
#'   those starting inside it).
#' @param out_dir Destination directory.
#' @param dry_run Only return the file manifest without downloading.
#' @param delay,overwrite,quiet,progress Passed to [glass_download()].
#'
#' @return A tibble manifest; with download `status` when not a dry run.
#'
#' @export
glass_fetch <- function(variant_id, from, to, roi = NULL, tiles = NULL,
                        doys_mode = c("span", "start"), out_dir,
                        dry_run = FALSE, delay = 1, overwrite = FALSE,
                        quiet = FALSE, progress = NULL) {
  if (!is.null(roi) && !is.null(tiles)) {
    glass_abort("Pass either `roi` or `tiles`, not both")
  }
  # 两者都空 = 全球 CMG 产品(无瓦片概念);瓦片型产品必须给其一
  t_sel <- if (!is.null(tiles)) tiles else if (!is.null(roi)) glass_tiles_for_sf(roi) else NULL
  if (!isTRUE(quiet) && is.null(tiles) && !is.null(t_sel)) {
    cat("ROI covers tiles:",
        paste(sprintf("h%02dv%02d", t_sel$h, t_sel$v), collapse = ", "), "\n")
  }

  doys <- glass_doys(variant_id, from, to, mode = doys_mode)
  if (nrow(doys) == 0L) {
    message("date range selects no composite folder")
    return(tibble::tibble())
  }

  manifest <- list()
  for (i in seq_len(nrow(doys))) {
    m <- glass_list_files(variant_id, year = doys$year[i], doy = doys$doy[i],
                          tiles = t_sel)
    if (!isTRUE(quiet)) {
      cat(sprintf("  %s / %d DOY %03d: %d files\n",
                  variant_id, doys$year[i], doys$doy[i], nrow(m)))
    }
    if (nrow(m) > 0L) manifest[[length(manifest) + 1L]] <- m
    if (i < nrow(doys)) Sys.sleep(0.3)
  }
  if (length(manifest) == 0L) {
    message("no files found for the query")
    return(tibble::tibble())
  }
  manifest <- dplyr::bind_rows(manifest)
  manifest <- manifest[!duplicated(manifest$filename), , drop = FALSE]

  if (dry_run) return(manifest)
  glass_download(manifest, out_dir = out_dir, delay = delay,
                 overwrite = overwrite, quiet = quiet, progress = progress)
}
