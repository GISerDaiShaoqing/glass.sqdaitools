# 一次性构建期脚本:批量核验未核验变体(样例 granule -> 命名片段 + cadence + 波段元数据)
# 输出:data-raw/verified_overlay.csv(累加,由 build_registry.R 叠加进登记表)
#      data-raw/verify_batch_log.csv(逐变体状态台账)
# 样例下载到 data-raw/samples/(gitignore;核验成功后即删,失败保留供排查)
# 幂等:已写入 overlay 的变体自动跳过,中断后可直接重跑续传
# 运行: Rscript data-raw/verify_batch.R
library(httr2)
library(rvest)
library(dplyr)
library(tibble)

FAMILIES <- c("LST", "ET", "GPP", "Albedo", "FAPAR")  # 本轮目标产品族;NULL = 全部
TARGET_IDS <- "LST_MODIS_Daily"  # 本轮定点重验:档案把年层挪到 1KM/ 下,需刷新 url_root
MAX_SAMPLE_MB <- 200         # 样例大小上限,超出只核验命名不测波段
REFRESH <- TRUE              # TRUE 强制重跑 overlay 里已有的变体
RECHECK_FILL_NA <- FALSE     # TRUE 追加重测 overlay 里 fill=NA 的行(如 GeoTIFF nodata 回退后)
SAMPLES <- "data-raw/samples"
OVERLAY_CSV <- "data-raw/verified_overlay.csv"
LOG_CSV <- "data-raw/verify_batch_log.csv"
UA <- "glass.sqdaitools-build/0.1 (R; contact dsq1993qingge@163.com)"
dir.create(SAMPLES, showWarnings = FALSE)

say <- function(...) cat(sprintf(...), "\n", sep = "")

get_hrefs <- function(url) {
  tryCatch(
    request(url) |>
      req_user_agent(UA) |>
      req_timeout(30) |>
      req_retry(max_tries = 3, backoff = ~ 8 * 3^.x) |>
      req_perform() |>
      resp_body_string() |>
      (\(t) read_html(t) |> html_elements("a") |> html_attr("href"))(),
    error = function(e) character(0)
  )
}
# 归档服务器对连续请求会间歇限速:空结果冷却后重试一次
get_hrefs_cool <- function(url) {
  h <- get_hrefs(url)
  if (!length(h)) {
    Sys.sleep(15)
    h <- get_hrefs(url)
  }
  h
}
clean <- function(x) sub("/$", "", x)

# 递归下探找"年份层"(归档层级深浅不一:有的产品在 res/ 与年份之间还有
# 版本子目录,如 GPP/MODIS/500M/GLASS_GPP_500M_V60/2018/...)
find_year_layer <- function(url, max_depth = 3) {
  raw <- get_hrefs(url)
  hrefs <- clean(raw)
  years <- grep("^[0-9]{4}$", hrefs, value = TRUE)
  if (length(years)) {
    return(list(url = url, years = sort(years, decreasing = TRUE)))
  }
  if (max_depth <= 0L) return(NULL)
  subdirs <- raw[grepl("/$", raw)]          # 尾斜杠只在原始 hrefs 里
  subdirs <- subdirs[!subdirs %in% c("../", "/")]
  for (sd in subdirs) {
    cand <- find_year_layer(paste0(url, sd), max_depth - 1L)
    if (!is.null(cand)) return(c(cand, list(via = c(sd, cand$via))))
  }
  NULL
}

# ---------- 目录结构探测 ----------
# 在目录里挑样例 granule(.hdf > .nc/.nc4 > .tif/.tiff > .dat;优先 h25v05 陆区瓦片);
# 无数据文件时进入第一个子目录再找一层
.glass_data_exts <- "\\.((hdf)|(nc4?)|(tiff?)|(dat))$"
pick_file <- function(raw, base_url) {
  hrefs <- clean(raw)
  hdf <- grep("\\.hdf$", hrefs, value = TRUE)
  if (!length(hdf)) hdf <- grep("\\.nc4?$", hrefs, value = TRUE, ignore.case = TRUE)
  if (!length(hdf)) hdf <- grep("\\.tiff?$", hrefs, value = TRUE, ignore.case = TRUE)
  if (!length(hdf)) hdf <- grep("\\.dat$", hrefs, value = TRUE, ignore.case = TRUE)
  prefix <- ""
  if (!length(hdf)) {
    subdirs <- raw[grepl("/$", raw)]
    subdirs <- subdirs[!subdirs %in% c("../", "/")]
    if (!length(subdirs)) return(NULL)
    inner <- get_hrefs(paste0(base_url, subdirs[1]))
    ih <- clean(inner)
    hdf <- grep("\\.hdf$", ih, value = TRUE)
    if (!length(hdf)) hdf <- grep("\\.nc4?$", ih, value = TRUE, ignore.case = TRUE)
    if (!length(hdf)) hdf <- grep("\\.tiff?$", ih, value = TRUE, ignore.case = TRUE)
    if (!length(hdf)) hdf <- grep("\\.dat$", ih, value = TRUE, ignore.case = TRUE)
    if (!length(hdf)) return(NULL)
    prefix <- subdirs[1]
  }
  hit <- grep("h25v05", hdf, value = TRUE)
  if (!length(hit)) hit <- grep("(?i)qc", hdf, value = TRUE, perl = TRUE, invert = TRUE)
  if (!length(hit)) hit <- hdf
  paste0(prefix, hit[1])
}

# ---------- 命名片段解析 ----------
parse_name <- function(fn) {
  parts <- strsplit(fn, ".", fixed = TRUE)[[1]]
  # code = 文件名第一段:GLASS01D01 / GHOSE03G01 / GLASS-MODIS-SRF-j 等归档真实前缀
  code <- if (grepl("^[A-Z][A-Za-z0-9-]{3,24}$", parts[1]) &&
              !grepl("^20[0-9]{5}$", parts[1])) parts[1] else NA_character_
  version <- if (length(parts) >= 2 && grepl("^V[0-9]+$", parts[2])) parts[2] else NA_character_
  layer <- NA_character_
  if (length(parts) >= 6) {
    cand <- parts[length(parts) - 1L]
    if (!grepl("^h[0-9]+v[0-9]+$", cand) && !grepl("^A[0-9]{7}$", cand) &&
        !grepl("^20[0-9]{5}$", cand) && cand != "hdf") {
      layer <- cand
    }
  }
  list(code = code, version = version, layer = layer)
}

# ---------- cadence 推断(由 DOY 目录间距) ----------
infer_cadence <- function(doys) {
  d <- sort(as.integer(doys))
  if (!length(d) || d[1] != 1L) {
    return(list(cadence = NA_integer_, label = NA_character_,
                note = if (length(d)) sprintf("first composite DOY is %03d", d[1]) else "no DOY folders"))
  }
  diffs <- diff(d)
  mdiff <- as.integer(names(sort(table(diffs), decreasing = TRUE))[1])
  if (mdiff == 1L) {
    list(cadence = 1L, label = "daily", note = NA_character_)
  } else if (mdiff == 8L) {
    list(cadence = 8L, label = "8 days", note = NA_character_)
  } else if (mdiff == 4L) {
    list(cadence = 4L, label = "4 days", note = NA_character_)
  } else if (all(diffs %in% 28:31)) {
    list(cadence = NA_integer_, label = "monthly",
         note = "monthly cadence; glass_doys() uniform-DOY model does not apply")
  } else {
    list(cadence = NA_integer_, label = sprintf("%d days (irregular)", mdiff),
         note = sprintf("irregular DOY spacing, mode=%d; manual check advised", mdiff))
  }
}

# ---------- 样例下载 ----------
remote_size <- function(url) {
  tryCatch({
    r <- request(url) |> req_user_agent(UA) |> req_timeout(60) |>
      req_method("HEAD") |> req_perform()
    s <- as.numeric(resp_headers(r)[["Content-Length"]])
    if (is.finite(s) && s > 0) s else NA_real_
  }, error = function(e) NA_real_)
}

download_sample <- function(url, dest) {
  rs <- remote_size(url)
  if (is.finite(rs) && rs > MAX_SAMPLE_MB * 1024^2) return("too_large")
  if (file.exists(dest) && is.finite(rs) && file.size(dest) == rs) {
    say("    样例已存在(%.1f MB),跳过下载", rs / 1024^2)
    return("ok")
  }
  tryCatch({
    request(url) |> req_user_agent(UA) |> req_timeout(900) |>
      req_perform(path = paste0(dest, ".part"))
    file.rename(paste0(dest, ".part"), dest)
    "ok"
  }, error = function(e) paste0("download_error: ", conditionMessage(e)))
}

# ---------- 波段元数据测量(terra::describe 的 GDAL 属性行) ----------
# 格式(实测 LAI V60 自校准): fillvalue=255 / scale_factor=0.1 / valid_range=0, 100 (raw)
measure_bands <- function(path) {
  d <- paste(tryCatch(terra::describe(path), error = function(e) character(0)),
             collapse = "\n")
  # 多 SDS 产品(HDF4_EOS EOS_GRID)属性嵌在子数据集层:顶层抓不到时下探 SDS1
  sds_all <- unlist(regmatches(d, gregexpr("(?i)SUBDATASET_[0-9]+_NAME=[^\n]+", d)))
  n_sds <- max(1L, length(unique(sds_all)))
  if (!grepl("(?i)fillvalue", d) && length(sds_all)) {
    sds1 <- sub("^[^=]+=", "", sds_all[1])
    d2 <- paste(tryCatch(terra::describe(sds1), error = function(e) character(0)),
                collapse = "\n")
    if (nzchar(d2)) d <- paste(d, d2, collapse = "\n")
  }
  if (!nzchar(d)) {
    return(list(fill = NA, scale = NA, vmin = NA, vmax = NA,
                long_name = NA, n_sds = NA, sds_labels = NA_character_, raw = ""))
  }
  grab_num <- function(key) {
    m <- regmatches(d, regexpr(paste0("(?i)", key, "\\s*[=:]\\s*[-0-9.eE+]+"), d))
    if (!length(m)) return(NA_real_)
    as.numeric(sub(paste0("(?i)", key, "\\s*[=:]\\s*"), "", m, perl = TRUE))
  }
  fill <- grab_num("_?fillvalue")
  if (is.na(fill)) fill <- grab_num("nodata\\s*value")   # GeoTIFF: NoData Value=
  # scale 只认明确来源,避免误抓无关的大写 SCALE 属性:
  # 1) scale_factor=...  2) GDAL "Offset: a,   Scale:b" 行
  scale <- grab_num("scale_factor")
  if (is.na(scale)) {
    m <- regmatches(d, regexpr("(?i)offset\\s*:\\s*[-0-9.eE+]+\\s*,\\s*scale\\s*:\\s*[-0-9.eE+]+", d))
    if (length(m)) scale <- as.numeric(sub("(?i).*scale\\s*:\\s*", "", m, perl = TRUE))
  }
  vr <- regmatches(d, regexpr("(?i)valid_range\\s*=\\s*[-0-9.eE+]+\\s*,\\s*[-0-9.eE+]+", d))
  ln <- regmatches(d, regexpr("(?i)long_name\\s*=[^\n]+", d))
  sds_labels <- NA_character_
  if (length(sds_all)) {
    labs <- unique(vapply(sds_all, function(s) {
      lab <- sub(".*?:(GLASS[A-Z0-9]+:[^\"\n]+)$", "\\1", s, perl = TRUE)
      if (lab == s) {  # 无 GLASS 前缀时只取冒号后两段,避免把本机路径写进台账
        parts <- strsplit(gsub('"', "", s), ":")[[1]]
        paste(tail(parts, 2), collapse = ":")
      } else lab
    }, character(1), USE.NAMES = FALSE))
    sds_labels <- paste(labs, collapse = "/")
  }
  if (length(vr)) {
    v <- as.numeric(strsplit(sub("(?i)valid_range\\s*=\\s*", "", vr, perl = TRUE),
                             ",\\s*")[[1]])
    vmin <- if (!is.na(scale)) v[1] * scale else v[1]
    vmax <- if (!is.na(scale)) v[2] * scale else v[2]
  } else {
    vmin <- vmax <- NA_real_
  }
  list(fill = fill, scale = scale, vmin = vmin, vmax = vmax,
       long_name = if (length(ln)) sub("(?i)long_name\\s*=\\s*", "", ln, perl = TRUE) else NA,
       n_sds = n_sds, sds_labels = sds_labels, raw = d)
}

# ---------- 主循环 ----------
e <- new.env()
load("data/glass_products.rda", envir = e)
gp <- e$glass_products

# TARGET_IDS 配 REFRESH 时,允许把已 verified 的变体拉回来重测
force_ids <- if (isTRUE(REFRESH) && !is.null(TARGET_IDS)) TARGET_IDS else character(0)
targets <- gp[(is.null(FAMILIES) | gp$product %in% FAMILIES) &
                (!gp$verified | gp$variant_id %in% force_ids),
              c("variant_id", "url_root", "layout")]
if (RECHECK_FILL_NA && file.exists(OVERLAY_CSV)) {
  ov0 <- read.csv(OVERLAY_CSV, stringsAsFactors = FALSE)
  extra <- gp[gp$variant_id %in% ov0$variant_id[is.na(ov0$fill_value)],
              c("variant_id", "url_root", "layout")]
  targets <- rbind(targets, extra[!extra$variant_id %in% targets$variant_id, ])
}
done <- if (file.exists(OVERLAY_CSV) && !REFRESH)
  read.csv(OVERLAY_CSV, stringsAsFactors = FALSE)$variant_id else character(0)
targets <- targets[!targets$variant_id %in% done, ]
if (!is.null(TARGET_IDS)) targets <- targets[targets$variant_id %in% TARGET_IDS, ]
say("目标 %d 个变体(已跳过 %d 个已完成)", nrow(targets), length(done))

overlay_rows <- list(); log_rows <- list()
for (k in seq_len(nrow(targets))) {
  vid <- targets$variant_id[k]; root <- targets$url_root[k]
  say("[%d/%d] %s", k, nrow(targets), vid)
  row <- tibble(variant_id = vid, observed_years = NA_character_,
                version = NA_character_, code = NA_character_, layer = NA_character_,
                layout = NA_character_,
                cadence_days = NA_integer_, temporal_res = NA_character_,
                fill_value = NA_real_, scale_factor = NA_real_,
                valid_min = NA_real_, valid_max = NA_real_, verified = FALSE,
                url_root = NA_character_,
                notes = NA_character_)
  lg <- list(variant_id = vid, status = NA, file_sample = NA,
             fill_value = NA, scale_factor = NA, valid_min = NA, valid_max = NA,
             cadence_days = NA, note = NA)

  # 1) 递归找年份层;找不到时尝试 flat/climatology 结构
  yl <- find_year_layer(root)
  Sys.sleep(0.3)
  cad <- list(cadence = NA_integer_, label = NA_character_, note = NA_character_)
  doy_url <- NULL
  if (!is.null(yl)) {
    row$observed_years <- paste(range(yl$years), collapse = "-")
    if (!is.null(yl$via)) {
      # 年层在 res/ 之下还包了版本/分辨率目录:把真实年层 URL 写进 overlay,
      # 其余 overlay 行此列为 NA,build_registry 合并时不会覆盖骨架值
      row$url_root <- yl$url
      row$notes <- paste0("data under ", paste(yl$via, collapse = "/"), "/")
    }
    # 逐年(最新优先)探测三种布局:DOY 目录 / YYYYDDD 日目录 / 年下直放数据文件;
    # 找到第一个有数据的年即用(避免空年份耗尽候选窗口)
    best <- NULL
    for (y in yl$years) {
      hrefs <- clean(get_hrefs_cool(paste0(yl$url, y, "/")))
      say("    [probe] y=%s nhrefs=%d url=%s via=%s", y, length(hrefs), yl$url,
          if (is.null(yl$via)) "-" else paste(yl$via, collapse = "/"))
      Sys.sleep(0.3)
      doys <- grep("^[0-9]{3}$", hrefs, value = TRUE)
      d8 <- grep("^[0-9]{7}$", hrefs, value = TRUE)   # YYYYDDD 目录名 = 4+3 = 7 位
      dfiles <- grep(.glass_data_exts, hrefs, value = TRUE, ignore.case = TRUE)
      if (length(doys)) {
        best <- list(n = length(doys), kind = "doy", doys = doys,
                     url = paste0(yl$url, y, "/"), year = y)
        break
      } else if (length(d8) && all(substr(d8, 1, 4) == y)) {
        # YYYYDDD 日目录布局(如 AWGF_LST):目录名即 year+doy
        best <- list(n = length(d8), kind = "yyyddd", doys = substr(d8, 5, 7),
                     url = paste0(yl$url, y, "/"), year = y)
        break
      } else if (length(dfiles)) {
        # 年份层下直接放数据文件:从文件名 A{y}{ddd} 抽 DOY 推 cadence
        best <- list(n = 0L, kind = "files", doys = character(0),
                     url = paste0(yl$url, y, "/"), dfiles = dfiles, year = y)
        break
      }
    }
    if (is.null(best)) {
      lg$status <- "failed: year folders exist but none has DOY/YYYYDDD sub-dirs or data files"
      say("    !! %s", lg$status)
      log_rows[[length(log_rows) + 1]] <- lg; next
    }
    if (best$kind == "doy") {
      cad <- infer_cadence(best$doys)
      doy_url <- paste0(best$url, sprintf("%03d", max(as.integer(best$doys))), "/")
    } else if (best$kind == "yyyddd") {
      cad <- infer_cadence(best$doys)
      note8 <- "YYYYDDD daily-folder layout (layout=year_yyyddd)"
      cad$note <- if (is.na(cad$note)) note8 else paste(cad$note, note8)
      d8max <- max(as.integer(paste0(best$year, best$doys)))
      doy_url <- paste0(best$url, sprintf("%07d", d8max), "/")
      row$layout <- "year_yyyddd"
    } else {
      dd <- unique(regmatches(best$dfiles, regexpr("A[0-9]{7}", best$dfiles)))
      if (length(dd)) {
        cad <- infer_cadence(sub("^A[0-9]{4}", "", dd))
        cad$note <- if (is.na(cad$note)) "files sit directly under year folders (layout=year_files)"
                    else paste(cad$note, "files sit directly under year folders (layout=year_files)")
      } else {
        cad$note <- "files sit directly under year folders, names without A{y}{ddd} (layout=year_files)"
      }
      doy_url <- best$url
      row$layout <- "year_files"
    }
    row$cadence_days <- cad$cadence
    row$temporal_res <- cad$label
  } else {
    cad$note <- "no year layer under root; trying flat file collection at root"
    row$layout <- "flat"
  }
  Sys.sleep(0.3)

  # 2) DOY 目录选样例文件(flat 结构则直接在 root 找)
  fn <- if (!is.null(doy_url)) pick_file(get_hrefs_cool(doy_url), doy_url) else NULL
  if (is.null(fn) && is.null(doy_url)) fn <- pick_file(get_hrefs_cool(root), root)
  if (is.null(fn)) {
    lg$status <- if (!is.null(doy_url)) "failed: no .hdf in composite folder"
                 else "failed: unexpected structure (climatology/flat, no .hdf at root)"
    say("    !! %s", lg$status)
    lg$cadence_days <- row$cadence_days; lg$note <- cad$note
    log_rows[[length(log_rows) + 1]] <- lg; next
  }
  full_url <- paste0(if (!is.null(doy_url)) doy_url else root, fn)
  pn <- parse_name(fn)
  row$code <- pn$code; row$version <- pn$version; row$layer <- pn$layer
  lg$file_sample <- fn
  say("    样例: %s", fn)

  if (is.na(row$code)) {
    # flat/年文件/YYYYDDD 日目录集合(命名非 GLASS 代码)也放行;DOY 目录型时间序列必须可匹配
    if (identical(row$layout, "flat") || identical(row$layout, "year_files") ||
        identical(row$layout, "year_yyyddd")) {
      row$notes <- paste("flat file collection; no GLASS code prefix,",
                         "glass_list_files() will not code-filter this variant")
      say("    (flat 集合,code 记 NA: %s)", fn)
    } else {
      lg$status <- "failed: filename does not match GLASS code pattern"
      say("    !! %s (%s)", lg$status, fn)
      lg$cadence_days <- row$cadence_days; lg$note <- cad$note
      log_rows[[length(log_rows) + 1]] <- lg; next
    }
  }

  # 3) 下载样例(过大则只核验命名;子目录样例统一平铺存放)
  dest <- file.path(SAMPLES, basename(fn))
  dl <- download_sample(full_url, dest)
  if (dl == "too_large") {
    row$verified <- TRUE
    row$notes <- sprintf("naming verified from listing (%s); band metadata not measured (sample >%d MB)",
                         fn, MAX_SAMPLE_MB)
    lg$status <- "verified_naming_only"; lg$cadence_days <- row$cadence_days
    lg$note <- cad$note
    overlay_rows[[length(overlay_rows) + 1L]] <- row
    log_rows[[length(log_rows) + 1]] <- lg
    next
  }
  if (dl != "ok") {
    lg$status <- dl; lg$cadence_days <- row$cadence_days; lg$note <- cad$note
    say("    !! %s", lg$status)
    log_rows[[length(log_rows) + 1]] <- lg; next
  }

  # 4) 测波段元数据
  mb <- measure_bands(dest)
  row$fill_value <- mb$fill
  row$scale_factor <- mb$scale
  row$valid_min <- mb$vmin
  row$valid_max <- mb$vmax
  notes <- c(
    sprintf("verified against sample %s", fn),
    if (!is.na(mb$long_name)) paste0("SDS long_name: ", mb$long_name),
    if (!is.na(mb$n_sds) && mb$n_sds > 1)
      sprintf("multi-SDS file (n=%d): pass subds to glass_read() [%s]", mb$n_sds, mb$sds_labels),
    if (!is.na(mb$scale) && mb$scale > 1)
      "archive scale_factor > 1 (inflation semantics); check data units before analysis",
    cad$note,
    if (is.na(mb$fill)) "no fillvalue attribute found in GDAL metadata"
  )
  row$notes <- paste(notes[!is.na(notes)], collapse = "; ")
  row$verified <- TRUE
  lg$status <- if (is.na(mb$fill)) "verified_no_band_attrs" else "verified_full"
  lg$fill_value <- mb$fill; lg$scale_factor <- mb$scale
  lg$valid_min <- mb$vmin; lg$valid_max <- mb$vmax
  lg$cadence_days <- row$cadence_days; lg$note <- cad$note
  overlay_rows[[length(overlay_rows) + 1L]] <- row
  log_rows[[length(log_rows) + 1]] <- lg
  say("    -> fill=%s scale=%s valid=[%s, %s] cadence=%s",
      mb$fill, mb$scale, mb$vmin, mb$vmax, row$cadence_days)

  # 5) 成功即删样例,失败保留
  unlink(dest)
  Sys.sleep(1)
}

# ---------- 落盘(累加去重) ----------
if (length(overlay_rows)) {
  ov <- bind_rows(overlay_rows)
  old <- if (file.exists(OVERLAY_CSV)) read.csv(OVERLAY_CSV, stringsAsFactors = FALSE) else NULL
  ov <- bind_rows(ov, old) |> distinct(variant_id, .keep_all = TRUE)
  write.csv(ov, OVERLAY_CSV, row.names = FALSE)
  say("overlay 累计 %d 行 -> %s", nrow(ov), OVERLAY_CSV)
} else {
  say("本轮无新增核验行")
}
lg_df <- bind_rows(lapply(log_rows, \(x) as_tibble(x)))
old_lg <- if (file.exists(LOG_CSV)) read.csv(LOG_CSV, stringsAsFactors = FALSE) else NULL
lg_df <- bind_rows(lg_df, old_lg) |> distinct(variant_id, .keep_all = TRUE)
write.csv(lg_df, LOG_CSV, row.names = FALSE)
n_ok <- sum(grepl("^verified", lg_df$status[lg_df$variant_id %in% targets$variant_id]))
n_bad <- sum(grepl("^failed", lg_df$status[lg_df$variant_id %in% targets$variant_id]))
say("完成: %d 核验 / %d 失败(本轮目标 %d)", n_ok, n_bad, nrow(targets))
