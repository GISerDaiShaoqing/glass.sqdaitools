#' Fetch GLASS granules for a variant, ROI and date range in one call
#'
#' `glass_fetch()` orchestrates the full pipeline of the legacy scripts:
#' registry variant -> [glass_tiles_for_sf()] (or explicit `tiles`) ->
#' [glass_doys()] -> [glass_list_files()] per composite folder ->
#' [glass_download()].
#'
#' Three archive shapes are handled:
#'
#' * `layout = "flat"` — static whole-file exchanges (AGB, KGClim, Crops,
#'   Albedo ABI climatologies). The date range is ignored and the full
#'   root listing is returned.
#' * cadence known (`cadence_days`): composite DOY folders are computed
#'   with [glass_doys()] and each `<year>/<doy>/` folder is listed.
#' * cadence unknown (`cadence_days` is NA): self-scan. Each year folder
#'   intersecting the range is listed once and granules are filtered by
#'   composite codes parsed from their filenames (`A{yyyy}{ddd}`, month
#'   codes such as `.2010xx.`, or trailing 7-digit year codes). Single- or
#'   irregularly spaced composites keep the whole year; regular ones follow
#'   `doys_mode`. This covers products whose granules sit directly in year
#'   folders (FVC, Albedo AVHRR/MIX/0.5D, PAR, RN, SM, LST/AVHRR
#'   Daily-ODC, NDVI/MODIS 0.25°, TPSCE, AWGF LST), roots wrapped one
#'   level by a version dir (NPP), and year folders holding DOY sub-folders
#'   (Albedo MODIS 250M).
#'
#' The self-scan keeps the fetch path tolerant to registry omissions: when
#' an unmeasured variant turns out to have a different layout than the
#' skeleton assumption, it still resolves granules from what the archive
#' itself reports.
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
#'   those starting inside it). Same semantics in the self-scan branch,
#'   calibrated against the composite dates found in the year folder.
#' @param out_dir Destination directory.
#' @param dry_run Only return the file manifest without downloading.
#' @param delay,overwrite,quiet,progress Passed to [glass_download()].
#'
#' @return A tibble manifest; with download `status` when not a dry run.
#'
#' @export
#' @examples
#' \dontrun{
#' # verified cadence (fast path)
#' glass_fetch("LAI_MODIS_250M", "2018-08-01", "2018-08-31", tiles = "h28v05")
#' # cadence unknown (self-scan path)
#' glass_fetch("FVC_AVHRR_0_5D", "2018-08-01", "2018-09-30", dry_run = TRUE)
#' }
glass_fetch <- function(variant_id, from, to, roi = NULL, tiles = NULL,
                        doys_mode = c("span", "start"), out_dir,
                        dry_run = FALSE, delay = 1, overwrite = FALSE,
                        quiet = FALSE, progress = NULL) {
  doys_mode <- match.arg(doys_mode)
  if (!is.null(roi) && !is.null(tiles)) {
    glass_abort("Pass either `roi` or `tiles`, not both")
  }
  # 两者都空 = 全球 CMG 产品(无瓦片概念);瓦片型产品必须给其一
  t_sel <- if (!is.null(tiles)) tiles else if (!is.null(roi)) glass_tiles_for_sf(roi) else NULL
  if (!isTRUE(quiet) && is.null(tiles) && !is.null(t_sel) && nrow(t_sel) > 0L) {
    cat("ROI covers tiles:",
        paste(sprintf("h%02dv%02d", t_sel$h, t_sel$v), collapse = ", "), "\n")
  }

  info <- glass_product_info(variant_id = variant_id)
  from <- as.Date(from); to <- as.Date(to)
  if (anyNA(c(from, to))) {
    glass_abort("`from`/`to` must be valid dates (YYYY-mm-dd)")
  }
  if (from > to) glass_abort("`from` must not be later than `to`")

  cadence <- info$cadence_days[[1]]

  if (identical(info$layout[[1]], "flat")) {
    # 静态整幅文件集合(KGClim/AGB/Crops/ABI 气候态等):没有时间分格,
    # 日期区间不参与,直接列出根目录全量文件(放宽扩展名覆盖 .tif/.nc 类型)
    if (!isTRUE(quiet)) {
      cat("static file collection: ", variant_id,
          " - date range ignored, listing all files\n")
    }
    manifest <- glass_list_files(variant_id, ext = .glass_granule_exts())
    if (nrow(manifest) == 0L) {
      .glass_static_hint(info)
      return(tibble::tibble())
    }
  } else if (is.na(cadence)) {
    # cadence 未登记:目录自检 —— 逐年列出当期文件夹,按文件名复合码自适应过滤
    manifest <- .glass_fetch_selfscan(variant_id, info, from, to,
                                      t_sel, doys_mode, quiet)
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

# ---------- 内部:静态集合根目录诊断 ----------
.glass_granule_exts <- function() {
  c("hdf", "hdf.xml", "tif", "tiff", "nc", "nc4", "h5", "mat", "dat")
}

# flat 集合列空时的实用提示:根下是否还有一层可下探的子目录
.glass_static_hint <- function(info, max_show = 5L) {
  refs <- tryCatch(.glass_fetch_hrefs(info$url_root[[1]]),
                   error = function(e) character(0))
  dirs <- setdiff(refs[grepl("/$", refs)], "../")
  if (length(dirs)) {
    message(sprintf(
      "no granules directly under %s; the folder holds only %d sub-folders (%s). ",
      info$url_root[[1]], length(dirs),
      paste(utils::head(sub("/$", "", dirs), max_show), collapse = ", ")),
      "Data live one level down; check the GLASS site for this variant.")
  }
  invisible()
}

# ---------- 内部:cadence 未登记时的目录自检 ----------
# 对 from..to 覆盖的每个年份:
#   1) 列 `root/<year>/`;
#   2) 年下直接是 granule -> 按文件名复合码过滤日期(年度单文件保留全年);
#   3) 年下是数字 DOY 子目录 -> 按目录增量估 cadence,再按区间选目录下探;
#   4) 根下既无年份也无文件而只有一个包装目录(NPP …_V40/) -> 下探一级重试。
.glass_fetch_selfscan <- function(variant_id, info, from, to,
                                  t_sel, doys_mode, quiet) {
  root <- info$url_root[[1]]
  tile_ids <- .glass_tile_ids(
    if (is.null(t_sel) || !nrow(t_sel)) NULL else t_sel)

  if (!isTRUE(quiet)) {
    cat("cadence unknown for ", variant_id,
        " - self-scan of year folders, ", format(from), "..", format(to), "\n")
  }

  refs <- setdiff(.glass_fetch_hrefs_safe(root), "../")
  if (!length(refs)) {
    message("archive listing failed for ", variant_id)
    return(.glass_list_files_empty(variant_id))
  }

  # 版本包装目录下探(根下既无年份也无文件):
  # 探测前 8 个子目录,选含年份子目录者;有 YEARLY 聚合目录并存时优先非 YEARLY
  yr_dirs <- grep("^[0-9]{4}/$", refs, value = TRUE)
  if (!length(yr_dirs) && !length(refs[!grepl("/$", refs)])) {
    dirs0 <- refs[grepl("/$", refs)]
    if (length(dirs0) <= 8L) {
      hits <- character(0)
      for (d in dirs0) {
        r2 <- .glass_fetch_hrefs_safe(paste0(root, d))
        if (length(grep("^[0-9]{4}/$", r2, value = TRUE))) hits <- c(hits, d)
        if (length(hits) > 3L) break
        Sys.sleep(0.2)
      }
      if (length(hits)) {
        pick <- hits[!grepl("yearly|annual", hits, ignore.case = TRUE)]
        if (!length(pick)) pick <- hits
        root <- paste0(root, pick[1L])
        if (!isTRUE(quiet)) cat("descending into version wrapper: ", root, "\n")
        refs <- setdiff(.glass_fetch_hrefs_safe(root), "../")
        yr_dirs <- grep("^[0-9]{4}/$", refs, value = TRUE)
      }
    }
  }

  # 根下直接是 granule(罕见形态):按当前区间一次列出
  if (!length(yr_dirs)) {
    if (!length(refs[!grepl("/$", refs)])) {
      message("no year folders and no granules under ", root,
              " - check the GLASS site for this variant")
      return(.glass_list_files_empty(variant_id))
    }
    m <- .glass_year_manifest(variant_id, info, refs[!grepl("/$", refs)],
                              root, tile_ids)
    m <- .glass_year_filter(m, from, to, doys_mode)
    return(if (is.null(m) || !nrow(m)) .glass_list_files_empty(variant_id) else m)
  }

  y_avail <- as.integer(sub("/$", "", yr_dirs))
  years_todo <- intersect(
    seq(as.integer(format(from, "%Y")), as.integer(format(to, "%Y")), 1L),
    y_avail)

  manifest <- list()
  for (yy in years_todo) {
    refs2 <- setdiff(.glass_fetch_hrefs_safe(paste0(root, yy, "/")), "../")
    if (!length(refs2)) next
    files2 <- refs2[!grepl("/$", refs2)]
    folds2 <- refs2[grepl("/$", refs2)]
    m <- NULL
    if (length(files2) || !length(folds2)) {
      # 年下直接是 granule(或年目录为空)
      m <- .glass_year_manifest(variant_id, info, files2,
                                paste0(root, yy, "/"), tile_ids)
      if (!is.null(m) && nrow(m)) m <- .glass_year_filter(m, from, to, doys_mode)
    } else {
      # DOY 子目录形态:按目录号的年度增量估步长,再按区间选目录
      m <- .glass_scan_doy_dirs(variant_id, info, root, yy, folds2,
                                tile_ids, from, to, doys_mode)
    }
    if (!is.null(m) && nrow(m) > 0L) manifest[[length(manifest) + 1L]] <- m
    if (!isTRUE(quiet)) {
      n_i <- if (is.null(m)) 0L else nrow(m)
      cat(sprintf("  %s / year %d: %d files\n", variant_id, yy, n_i))
    }
    Sys.sleep(0.3)
  }

  if (!length(manifest)) {
    message("no files found between ", format(from), " and ", format(to))
    return(.glass_list_files_empty(variant_id))
  }
  out <- dplyr::bind_rows(manifest)
  out[!duplicated(out$filename), , drop = FALSE]
}

# 数字化的复合码 -> Date;月刊码 6 位(YYYYMM,年=前 4 位),doy 码 7 位
.glass_code_start <- function(code, month_mode) {
  stopifnot(is.integer(code))
  out <- rep(as.Date(NA), length(code))
  if (isTRUE(month_mode)) {
    ty <- code %/% 100L
    v <- code %% 100L
    ok <- !is.na(v) & v >= 1L & v <= 12L
    if (any(ok)) out[ok] <- as.Date(sprintf("%d-%02d-01", ty[ok], v[ok]))
  } else {
    ty <- code %/% 1000L
    v <- code %% 1000L
    ok <- !is.na(v) & v >= 1L & v <= 366L
    if (any(ok)) out[ok] <- as.Date(v[ok] - 1L, origin = sprintf("%d-01-01", ty[ok]))
  }
  out
}

# 一年文件夹(直接 granule)的清单构建 + 复合码解析
.glass_year_manifest <- function(variant_id, info, files, prefix, tile_ids) {
  files <- files[!grepl("\\.(jpg|png)$", files, ignore.case = TRUE)]
  if (!length(files)) return(NULL)
  code <- if (isTRUE(info$verified[[1]])) info$code[[1]] else NA_character_
  if (!is.na(code)) files <- files[startsWith(files, code)]
  if (!length(files)) return(NULL)
  if (!is.null(tile_ids) && length(tile_ids)) {
    files <- files[grepl(sprintf("(%s)", paste(tile_ids, collapse = "|")), files)]
  }
  if (!length(files)) return(NULL)
  ext_pat <- paste0("(", paste(
    vapply(.glass_granule_exts(), function(e) paste0("\\.", gsub("\\.", "\\\\.", e), "$"),
           character(1)), collapse = "|"), ")")
  files <- files[grepl(ext_pat, files, ignore.case = TRUE)]
  if (!length(files)) return(NULL)

  # 复合码识别(按优先级/位置):
  #   1) A+7 位,如 A2018217(LAI/FVC/Albedo 的主流命名);
  #   2) 6 位月刊码(需非数字边界,如 GLASS13J01.201001.);
  #   3) 7 位 doy 码(如 Combined_TPSCE_1981213.dat / global_…_2011001.nc)。
  # 同一行里 6 位与 7 位候选并存时取位置更早者(月码先于版本时间戳出现)。
  team <- rep(NA_integer_, length(files))          # 编码:月刊码按 YYYYMM;doy 码按 YYYYDDD
  sma <- regexpr("A[0-9]{7}", files)
  ia <- which(sma > 0L)
  if (length(ia)) {
    team[ia] <- as.integer(substr(files[ia], sma[ia] + 1L, sma[ia] + 7L))
  }
  # 7 位候选:19xx/20xx 起头的 7 位数
  sk7 <- regexpr("(19|20)[0-9]{5}", files)
  # 6 位候选:跟着一个非数字边界,避免切进 7 位 doy 码内部
  sm6 <- regexpr("(19|20)[0-9]{4}[^0-9]", files)
  i6 <- which(sma < 0L & sm6 > 0L & (sk7 < 0L | sm6 < sk7))
  i7 <- which(sma < 0L & sk7 > 0L & !(sm6 > 0L & sm6 < sk7))
  if (length(i6)) {
    team[i6] <- as.integer(substr(files[i6], sm6[i6], sm6[i6] + 5L))
  }
  if (length(i7)) {
    team[i7] <- as.integer(substr(files[i7], sk7[i7], sk7[i7] + 6L))
  }

  # 月刊码判定:本文件夹 6 位候选 >= 7 位候选时按 YYYYMM 解读;
  # 混入的无月码行(常是版本时间戳)一律置 NA,不猜测 doy 语义
  month_mode <- length(i6) > 0L && length(i6) >= length(i7)
  if (month_mode) team[i7] <- NA_integer_
  div <- ifelse(month_mode, 100L, 1000L)
  yr_tok <- ifelse(is.na(team), NA_integer_, team %/% div)
  starts <- .glass_code_start(team, month_mode)

  exts <- tools::file_ext(files)
  exts[endsWith(files, ".hdf.xml")] <- "hdf.xml"
  tdoy <- rep(NA_integer_, length(files))
  vi <- which(!is.na(starts))
  if (length(vi)) tdoy[vi] <- as.integer(format(starts[vi], "%j"))
  tibble::tibble(
    filename = files,
    url = paste0(prefix, files),
    variant_id = rep(variant_id, length(files)),
    year = yr_tok,
    doy = tdoy,
    tile = vapply(files, function(f) {
      mx <- regmatches(f, regexpr("h[0-9]{2}v[0-9]{2}", f))
      if (length(mx)) mx else NA_character_
    }, character(1), USE.NAMES = FALSE),
    ext = exts,
    start = starts
  )
}

# 年份颗粒的日期筛选(以文件夹内观测到的复合日期为准):
# - 唯一 start 或全部无 start -> 保留整年(年度单文件的覆盖就是一年)
# - start 模式:start 落在 [from, to]
# - span 模式:start <= to 且覆盖区(end = 下一个 start - 1;最后一个为年末) >= from
.glass_year_filter <- function(m, from, to, doys_mode) {
  starts <- m$start
  if (is.null(starts) || all(is.na(starts))) return(m)
  u <- sort(unique(starts[!is.na(starts)]))
  if (length(u) <= 1L) return(m)
  ov <- which(!is.na(starts))
  keep <- rep(TRUE, nrow(m))
  if (identical(doys_mode, "start")) {
    keep[ov] <- starts[ov] >= from & starts[ov] <= to
  } else {
    cover <- rep(as.Date(NA), nrow(m))
    for (ii in ov) {
      later <- u[u > starts[ii]]
      cover[ii] <- if (length(later)) later[1L] - 1L else
        as.Date(sprintf("%d-12-31", m$year[1L]))
    }
    keep[ov] <- starts[ov] <= to & !is.na(cover[ov]) & cover[ov] >= from
  }
  keep[is.na(starts)] <- TRUE   # 没解析出复合码的行保守保留
  m[keep, , drop = FALSE]
}

# 年份下是数字 DOY 子目录的形态(如 Albedo MODIS 250M 的 049/053/…):
# 按目录号排序,相邻差即为观测步长;按 from..to(span/start)选目录后逐个列出
.glass_scan_doy_dirs <- function(variant_id, info, root, yy, folds2,
                                 tile_ids, from, to, doys_mode) {
  dnum <- suppressWarnings(as.integer(sub("/$", "", folds2)))
  keep <- !is.na(dnum)
  folds2 <- folds2[keep]; dnum <- dnum[keep]
  if (!length(dnum)) return(NULL)
  ord <- order(dnum)
  folds2 <- folds2[ord]; dnum <- dnum[ord]

  y01 <- as.Date(sprintf("%d-01-01", yy))
  yend <- as.Date(sprintf("%d-12-31", yy))
  for (k in seq_along(dnum)) {
    d0 <- y01 + (dnum[k] - 1L)
    d1 <- if (k < length(dnum)) y01 + dnum[k + 1L] - 2L else yend
    ok <- if (identical(doys_mode, "start")) d0 >= from && d0 <= to
          else max(d1) >= from && d0 <= to
    if (!ok) next
    r3 <- .glass_fetch_hrefs_safe(paste0(root, yy, "/", folds2[k]))
    if (!length(r3)) next
    m <- .glass_year_manifest(variant_id, info, r3[!grepl("/$", r3)],
                              paste0(root, yy, "/", folds2[k]), tile_ids)
    if (!is.null(m) && nrow(m)) return(m)
  }
  NULL
}
