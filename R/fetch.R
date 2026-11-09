#' Fetch GLASS granules for a variant, ROI and date range in one call
#'
#' `glass_fetch()` orchestrates the full pipeline of the legacy scripts:
#' registry variant -> [glass_tiles_for_sf()] (or explicit `tiles`) ->
#' [glass_doys()] -> [glass_list_files()] per composite folder ->
#' [glass_download()].
#'
#' @param variant_id Registry variant key.
#' @param from,to Date range ("YYYY-mm-dd" or Date). Ignored for static
#'   file collections (`layout = "flat"`, e.g. AGB, KGClim, Crops): those
#'   are whole-file exchanges, so the full file list is fetched instead.
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

  info <- glass_product_info(variant_id = variant_id)

  if (identical(info$layout[[1]], "flat")) {
    # 静态整幅文件集合(KGClim/AGB 等):没有 DOY 分格,日期区间不参与,
    # 直接列出根目录全量文件(放宽扩展名以覆盖 .tif/.nc 类型)
    if (!isTRUE(quiet)) {
      cat("static file collection: ", variant_id,
          " - date range ignored, listing all files\n")
    }
    manifest <- glass_list_files(
      variant_id,
      ext = c("hdf", "hdf.xml", "tif", "tiff", "nc", "h5", "mat")
    )
    if (nrow(manifest) == 0L) {
      message("no files found for the static collection")
      return(tibble::tibble())
    }
  } else {
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
  }

  if (dry_run) return(manifest)
  glass_download(manifest, out_dir = out_dir, delay = delay,
                 overwrite = overwrite, quiet = quiet, progress = progress)
}
