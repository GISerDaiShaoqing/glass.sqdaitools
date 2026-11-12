# 内部:下载产品的地图叠加预览辅助(不导出;纯逻辑,便于离线单测)
# 管线思想:glass_read(注册表自填 fill/scale/valid_range) -> 多瓦片 glass_mosaic
#   -> terra::crop(ROI 外扩) -> terra::project("EPSG:4326", res=粗化分辨率)
#   -> leaflet::addRasterImage(project=TRUE, maxBytes=8MB)。

# 下载完成的清单行 -> 按 变体|年|合成期 分组的预览候选
# - status 白名单与 R/download.R 的写入词表一致;
# - 只有带 destfile 且本地文件存在的行才生成预览组(dry-run 行天然被剔);
# - doy 缺失(年度单文件,如 HiGLASS/AGB/KGClim)按“年度”成组。
.glass_preview_groups <- function(m) {
  empty <- data.frame(group_key = character(), label = character(),
                      n_files = integer(), variant_id = character(),
                      stringsAsFactors = FALSE)
  empty$destfiles <- list()
  if (is.null(m) || !nrow(m) || is.null(names(m)) ||
      !"destfile" %in% names(m)) return(empty)
  ok_status <- c("downloaded", "resumed", "resumed_partial", "skipped")
  keep <- m$status %in% ok_status &
          nzchar(m$destfile) & file.exists(m$destfile) &
          # .hdf.xml 等元数据伴随文件不是栅格,不进预览组(fetch 会连它一起下载)
          !grepl("\\.xml$", m$destfile, ignore.case = TRUE)
  mm <- m[keep, , drop = FALSE]
  n <- nrow(mm)
  if (!n) return(empty)

  doy_k <- ifelse(is.na(mm$doy), "-1", sprintf("%03d", as.integer(mm$doy)))
  gk <- paste(mm$variant_id, ifelse(is.na(mm$year), "NA", mm$year), doy_k, sep = "|")
  tiles <- ifelse(is.na(mm$tile) | !nzchar(mm$tile), "CMG", mm$tile)

  out <- data.frame(group_key = unique(gk), stringsAsFactors = FALSE)
  out$label <- vapply(out$group_key, function(k) {
    ii <- which(gk == k)
    tv <- unique(mm$tile[ii])
    tv <- unique(ifelse(is.na(tv) | !nzchar(tv), "CMG", tv))
    tlab <- paste(sort(tv), collapse = "+")
    yv <- ifelse(is.na(mm$year[ii][1]), "\u672a\u77e5", as.character(mm$year[ii][1]))
    per <- if (is.na(mm$doy[ii][1]))
      sprintf("%s \u5e74\u5ea6", yv) else sprintf("%s DOY%03d", yv, mm$doy[ii][1])
    txt <- if (identical(tlab, "CMG")) per else paste0(tlab, "\u00b7", per)
    sprintf("%s (%d \u6587\u4ef6)", txt, length(ii))
  }, character(1), USE.NAMES = FALSE)
  out$n_files <- as.integer(table(gk)[out$group_key])
  out$variant_id <- vapply(out$group_key, function(k) mm$variant_id[which(gk == k)][1],
                           character(1), USE.NAMES = FALSE)
  out$destfiles <- lapply(out$group_key, function(k) mm$destfile[which(gk == k)])
  out[, c("group_key", "label", "n_files", "variant_id", "destfiles")]
}

# 预览前 CRS 守卫:GLASS 的 HDF/栅粒带错 CRS(或根本没写)时有发生;
# 把中心点投到 4326,落在地球范围外即认定 CRS 不可信,按文件名形态强制纠正
# (hXXvYY -> MODIS 正弦球体 R=6371007.181;其余 -> EPSG:4326)。
.glass_preview_crs <- function(rr, destname) {
  # terra 1.9.27 起crs() 删除了 warn 参数,传了会报错被 tryCatch 吞掉,
  # 导致守卫永远不信任 CRS —— 这里必须裸调
  cr <- tryCatch(terra::crs(rr), error = function(e) "")
  trust <- !is.na(cr) && nzchar(trimws(cr))
  if (trust) {
    ok <- tryCatch({
      ex <- terra::ext(rr)
      cx <- (terra::xmin(ex) + terra::xmax(ex)) / 2
      cy <- (terra::ymin(ex) + terra::ymax(ex)) / 2
      pt <- terra::project(terra::vect(cbind(cx, cy), crs = cr),
                           "+proj=longlat +datum=WGS84 +no_defs")
      cd <- terra::crds(pt)
      abs(cd[1]) <= 360.5 && abs(cd[2]) <= 90.5
    }, error = function(e) FALSE)
    trust <- isTRUE(ok)
  }
  if (trust) return(rr)
  hv <- regmatches(destname, regexpr("h[0-9]{2}v[0-9]{2}", destname))
  crs_new <- if (length(hv)) "+proj=sinu +R=6371007.181 +units=m"
             else "+proj=longlat +datum=WGS84 +no_defs"
  message("preview: CRS looks missing/invalid for ", basename(destname),
          "; forcing ", crs_new)
  terra::crs(rr) <- crs_new
  rr
}

# 统一下采样:超过目标像素量时按 sqrt 比例聚合(连续量取均值)
.glass_downsample <- function(rr, target_px = 9e5) {
  n <- terra::ncell(rr)
  if (n <= target_px) return(rr)
  f <- ceiling(sqrt(n / target_px))
  terra::aggregate(rr, f, fun = mean, na.rm = TRUE)
}

# 枚举一个瓦片的可选预览层(叠加后供“波段”下拉切换):
# - 有子数据集(HDF4/NetCDF 多变量)时按 SDS 枚举,label 取 varname 冒号后的短名;
# - 否则按多图层枚举(GeoTIFF 多波段/netCDF 时间层),label 取图层名;
# - 空名回退 “SDS n/波段 n”;describe/rast 失败回退单层(维持旧行为)。
# 返回 data.frame(subds, layer, label):subds 为 1 基 SDS 序号(无 SDS 时 NA),
# layer 为该 SDS/文件内的图层序号,二者一起喂给 .glass_preview_raster。
.glass_preview_layers <- function(f) {
  fallback <- data.frame(subds = NA_integer_, layer = 1L,
                         label = "\u6ce2\u6bb5 1", stringsAsFactors = FALSE)
  d <- tryCatch(suppressWarnings(terra::describe(f, sds = TRUE)),
                error = function(e) NULL)
  if (!is.null(d) && nrow(d) > 0L) {
    vv <- if (!is.null(d$varname)) d$varname else d$name
    if (is.null(vv) || !length(vv)) return(fallback)
    lab <- sub("^.*[:/]", "", vv)
    bad <- is.na(lab) | !nzchar(lab)
    lab[bad] <- sprintf("SDS %d", which(bad))
    data.frame(subds = seq_len(nrow(d)), layer = 1L,
               label = make.unique(lab, sep = "_"), stringsAsFactors = FALSE)
  } else {
    r <- tryCatch(suppressWarnings(terra::rast(f)), error = function(e) NULL)
    if (is.null(r)) return(fallback)
    n <- terra::nlyr(r)
    lab <- terra::names(r)
    bad <- is.na(lab) | !nzchar(lab)
    lab[bad] <- sprintf("\u6ce2\u6bb5 %d", which(bad))
    data.frame(subds = rep(NA_integer_, n), layer = seq_len(n),
               label = make.unique(lab, sep = "_"), stringsAsFactors = FALSE)
  }
}

# 读单个瓦片的指定 SDS/图层;注册表 fill/scale/valid_range 按变体主层测量,
# 对 QC 等子层不适用时可能把整层洗成 NA —— 此时退回原始值读取,保证预览有东西可看。
# subds 为 1 基 SDS 序号(整数)或 NULL;SDS 经 terra::sds()[[i]] 选取(1 基,
# 与 GDAL 子数据集列表一致),不用 rast(subds=) 的数组索引语义。
.glass_read_layer <- function(f, variant_id, subds = NULL, layer = 1L) {
  layer <- suppressWarnings(as.integer(layer[1]))
  if (is.na(layer) || layer < 1L) layer <- 1L
  sds_idx <- 0L
  sds_col <- NULL
  if (!is.null(subds) && length(subds) == 1L && !is.na(subds)) {
    i <- suppressWarnings(as.integer(subds))
    if (!is.na(i) && i >= 1L) {
      sds_col <- tryCatch(suppressWarnings(terra::sds(f)),
                          error = function(e) NULL)
      n_sds <- if (is.null(sds_col)) 0L else
        if (inherits(sds_col, "SpatRaster")) terra::nlyr(sds_col) else
          length(sds_col)
      if (i <= n_sds) sds_idx <- i
    }
  }
  pick <- function(r) {
    n <- terra::nlyr(r)
    if (n > 1L) r <- r[[min(layer, n)]]
    r
  }
  read_one <- function(raw = FALSE) {
    if (sds_idx >= 1L) {
      r1 <- sds_col[[sds_idx]]
      if (raw) glass_read(r1) else glass_read(r1, product = variant_id)
    } else {
      if (raw) glass_read(f) else glass_read(f, product = variant_id)
    }
  }
  r1 <- pick(read_one(FALSE))
  ok_n <- tryCatch(terra::global(r1, function(x) sum(!is.na(x)))[[1]][1],
                   error = function(e) 1)
  if (isTRUE(ok_n == 0)) {
    message("preview: registry band metadata wipes this layer; reading raw values")
    r1 <- pick(read_one(raw = TRUE))
  }
  r1
}

# 预览拉伸域:minmax=全值域(leaflet 默认,与旧行为一致);p2_98=2%/98% 分位
# (geemap COG 路径默认),抗离群值。无有效值时返回 c(0, 1)。
.glass_preview_domain <- function(v, stretch = c("minmax", "p2_98")) {
  stretch <- match.arg(stretch)
  v <- v[is.finite(v)]
  if (!length(v)) return(c(0, 1))
  if (identical(stretch, "p2_98")) {
    as.numeric(stats::quantile(v, c(0.02, 0.98), names = FALSE))
  } else {
    c(min(v), max(v))
  }
}

# 预览成图管线:glass_read(登记表自填 fill/scale/valid_range) -> 多瓦片合并
#   -> ROI 外扩 0.5° 裁剪(自动对齐 0..360 约定) -> 长纬投影 + 统一下采样
#   -> 0..360 绕回 -180..180 -> (to_merc) 再投 webmerc 并控像素。
# subds/layer 指定渲染的 SDS/图层(可选层由 .glass_preview_layers 枚举);
# 返回单层 SpatRaster;to_merc=TRUE 时返回 EPSG:3857,配 leaflet
# addRasterImage(project=FALSE) 使用——绝不让 leaflet 内部自行推目标网格
# (其 std::vector 会爆)。
.glass_preview_raster <- function(destfiles, variant_id, roi_bbox = NULL,
                                  to_merc = TRUE, target_px = 9e5,
                                  subds = NULL, layer = 1L) {
  ok <- file.exists(destfiles)
  fl <- destfiles[ok]
  if (!length(fl)) {
    glass_abort("no local granules to preview - out_dir changed or files moved")
  }
  rlist <- lapply(fl, function(f) {
    # 单文件读取失败(伴随文件/损坏粒)自动跳过,不拖垮整组;全败才中止
    r1 <- tryCatch(
      .glass_read_layer(f, variant_id, subds = subds, layer = layer),
      error = function(e) {
        message(sprintf("preview: skipping %s (%s)", basename(f),
                        conditionMessage(e)))
        NULL
      })
    if (is.null(r1)) return(NULL)
    if (!is.null(roi_bbox) &&
        all(c("xmin", "xmax", "ymin", "ymax") %in% names(roi_bbox))) {
      e <- terra::ext(roi_bbox[["xmin"]] - 0.5, roi_bbox[["xmax"]] + 0.5,
                      roi_bbox[["ymin"]] - 0.5, roi_bbox[["ymax"]] + 0.5)
      # 文件是 0..360 经度约定而 ROI 是 -180..180 画框时,裁剪框右移 360 对齐
      if (terra::xmax(r1) > 180.5 && roi_bbox[["xmin"]] < 0) {
        e <- terra::shift(e, 360)
      }
      r1c <- tryCatch(terra::crop(r1, e), error = function(e2) r1)
      if (!terra::hasValues(r1c) || terra::ncell(r1c) == 0L) r1c <- r1  # 裁空则放弃裁剪
      r1 <- r1c
    }
    r1
  })
  rlist <- Filter(Negate(is.null), rlist)
  if (!length(rlist)) {
    glass_abort("no readable granules to preview - group has only sidecar (.hdf.xml) or damaged files")
  }
  rr <- if (length(rlist) > 1L) glass_mosaic(rlist) else rlist[[1]]
  if (terra::nlyr(rr) > 1L) rr <- rr[[1]]
  rr <- .glass_preview_crs(rr, fl[1])
  # 长纬投影:不指定 res(避免把正弦米制的 bbox 当度数),随后统一下采样
  rr <- terra::project(rr, "+proj=longlat +datum=WGS84 +no_defs",
                       method = "bilinear")
  rr <- .glass_downsample(rr, target_px)
  # 0..360 经度约定的 CMG(如 ABI 气候态 netCDF)绕回 -180..180;
  # terra::rotate 只认标准全球 0..360,其余形态手工切割重排
  if (terra::xmax(rr) > 180.5) {
    message("preview: longitude 0..360 convention detected; rotating to -180..180")
    e0 <- terra::ext(rr)
    is_global <- terra::xmin(e0) >= -0.5 && terra::xmax(e0) <= 360.5 &&
      (terra::xmax(e0) - terra::xmin(e0)) >= 355
    if (is_global) {
      rr <- terra::rotate(rr)
    } else {
      ymax <- terra::ymax(e0); ymin <- terra::ymin(e0)
      w <- terra::crop(rr, terra::ext(-0.5, 180.5, ymin, ymax))
      ee <- terra::crop(rr, terra::ext(max(180.5, terra::xmin(e0)),
                                       terra::xmax(e0), ymin, ymax))
      has_w <- terra::ncell(w) > 0L
      has_e <- terra::ncell(ee) > 0L
      if (has_e) ee <- terra::shift(ee, -360)
      rr <- if (has_e && has_w) terra::merge(ee, w)
            else if (has_e) ee
            else if (has_w) w
            else rr
    }
  }
  # 收尾:res 吸附可能把边界推过 180 一点,钳回 -180..180(webmerc 硬界限)
  if (terra::xmax(rr) > 180 || terra::xmin(rr) < -180) {
    rr <- terra::crop(rr, terra::ext(-180, 180, terra::ymin(rr), terra::ymax(rr)))
  }
  if (isTRUE(to_merc)) {
    # webmerc 只覆盖 ±85.05°;极地行不切掉,新版 GDAL warp 会报
    # "area of interest not accepted"(旧版容忍成巨 y,leaflet 里爆矩阵)
    rr <- .glass_clip_webmerc_lat(rr, lim = 85.0)
    # 模板栅格显式给定输出网格:标准方框 + 受控像素,极冠由 GDAL 填 NA
    MMAX <- 20037508.34
    side <- max(2L, ceiling(sqrt(max(target_px, 1e4))))
    tmpl <- terra::rast(terra::ext(-MMAX, MMAX, -MMAX, MMAX),
                        nrows = side, ncols = side, nlyr = 1L,
                        crs = "+proj=merc +a=6378137 +b=6378137 +lat_ts=0 +lon_0=0 +x_0=0 +y_0=0 +k=1 +units=m +nadgrids=@null +no_defs")
    rr <- terra::project(rr, tmpl, method = "bilinear")
  }
  rr
}

# 扫描导入:把"目录里已有的下载产物"识别成与下载清单同构的行,
# 供 .glass_preview_groups 使用——不需要任何 manifest。
# - 递归列出 .glass_granule_exts() 扩展名(剔除 jpg/png/hdr 预览砖);
# - 变体识别:文件首段 == 注册表 code;HiGLASS_LS20_* 按层名(LAI/FAPAR)
#   落到 LAI_HR_LAI_V01 / FAPAR_HR_FAPAR_V01;TPSCE/AWGF 裸命名走特殊规则;
# - 年/合成期:文件级 token(A+7 位 > 6 位月码 > 7 位年份码 > _2018_ 年度);
# - 不能识别变体的行直接剔除,n_unknown 属性给出计数。
.glass_scan_datetime <- function(name) {
  y <- rep(NA_integer_, length(name))
  d <- rep(NA_integer_, length(name))
  # 1) A+7 位(如 A2018217)
  sma <- regexpr("A[0-9]{7}", name)
  ia <- which(sma > 0L)
  if (length(ia)) {
    tok <- substr(name[ia], sma[ia] + 1L, sma[ia] + 7L)
    y[ia] <- as.integer(substr(tok, 1L, 4L))
    d[ia] <- as.integer(substr(tok, 5L, 7L))
  }
  # 2) 6 位月码(带非数字边界,如 .201001.)=> 2010 年 1 月
  sm6 <- regexpr("(19|20)[0-9]{4}[^0-9]", name)
  i6 <- which(sma < 0L & sm6 > 0L)
  if (length(i6)) {
    tok <- substr(name[i6], sm6[i6], sm6[i6] + 5L)
    y6 <- as.integer(substr(tok, 1L, 4L))
    m6 <- as.integer(substr(tok, 5L, 6L))
    ok <- m6 >= 1L & m6 <= 12L
    y[i6][ok] <- y6[ok]
    d[i6][ok] <- as.integer(format(as.Date(sprintf("%d-%02d-01", y6[ok], m6[ok])), "%j"))
  }
  # 3) 7 位 doy 码(Combined_TPSCE_1981213 / global_…_2011001)
  sk7 <- regexpr("(19|20)[0-9]{5}", name)
  i7 <- which(sma < 0L & sm6 < 0L & sk7 > 0L)
  if (length(i7)) {
    tok <- substr(name[i7], sk7[i7], sk7[i7] + 6L)
    y[i7] <- as.integer(substr(tok, 1L, 4L))
    d[i7] <- as.integer(substr(tok, 5L, 7L))
  }
  # 4) 独立四位年段(_2018_)=> 年度
  smy <- regexpr("_(19|20)[0-9]{2}_", name)
  iy <- which(sma < 0L & sm6 < 0L & sk7 < 0L & smy > 0L)
  if (length(iy)) {
    y[iy] <- as.integer(substr(name[iy], smy[iy] + 1L, smy[iy] + 4L))
  }
  list(year = y, doy = d)
}

.glass_scan_import <- function(dir, max_files = 5000L) {
  empty <- data.frame(filename = character(), url = character(),
                      variant_id = character(), year = integer(),
                      doy = integer(), tile = character(),
                      status = character(), destfile = character(),
                      stringsAsFactors = FALSE)
  empty$ext <- character()
  empty$size_bytes <- numeric()
  if (!nzchar(dir) || !dir.exists(dir)) {
    glass_abort(sprintf("'%s' is not an existing directory", dir))
  }
  pat <- paste0("\\.(?:", paste(gsub("\\.", "\\\\.",
    .glass_granule_exts()), collapse = "|"), ")$")
  fl <- list.files(dir, pattern = pat, recursive = TRUE,
                   ignore.case = TRUE, full.names = TRUE)
  fl <- fl[!grepl("\\.(jpg|png|hdr)$", fl, ignore.case = TRUE)]
  if (!length(fl)) return(empty)
  if (length(fl) > max_files) {
    glass_abort(sprintf("too many files found (%d); narrow the directory", length(fl)))
  }
  reg <- glass_registry(verified_only = FALSE)
  v2 <- reg$variant_id[!is.na(reg$code)]
  k2 <- reg$code[!is.na(reg$code)]
  code2var <- vapply(split(v2, k2), function(x) x[1], character(1))
  base_only <- basename(fl)
  vid <- rep(NA_character_, length(fl))
  special <- grepl("^HiGLASS_LS20_", base_only)
  vid[special] <- ifelse(grepl("_LAI\\.", base_only[special]),
                         "LAI_HR_LAI_V01", "FAPAR_HR_FAPAR_V01")
  vid[grepl("^Combined_TPSCE", base_only) & is.na(vid)] <- "TPSCE_AVHRR"
  vid[grepl("^global_hourly_all_sky", base_only) & is.na(vid)] <- "AWGF_LST_GHA-LST"
  code <- vapply(base_only, function(f) {
    p <- strsplit(f, ".", fixed = TRUE)[[1]][1]
    if (grepl("^[A-Z][A-Za-z0-9-]{3,24}$", p) && !grepl("^20[0-9]{5}$", p)) p else NA_character_
  }, character(1), USE.NAMES = FALSE)
  ina <- which(is.na(vid) & !is.na(code))
  if (length(ina)) vid[ina] <- code2var[code[ina]]
  keep <- !is.na(vid)
  n_unknown <- sum(!keep)
  fl <- fl[keep]; vid <- vid[keep]; base_only <- base_only[keep]
  if (!length(fl)) {
    out <- empty
    attr(out, "n_unknown") <- n_unknown
    return(out)
  }
  yd <- .glass_scan_datetime(base_only)
  tile <- vapply(base_only, function(f) {
    mx <- regmatches(f, regexpr("h[0-9]{2}v[0-9]{2}", f))
    if (!length(mx)) mx <- regmatches(f, regexpr("[ns][0-9]{3}[ew][0-9]{3}", f))
    if (length(mx)) mx else NA_character_
  }, character(1), USE.NAMES = FALSE)
  exts <- tools::file_ext(base_only)
  exts[endsWith(base_only, ".hdf.xml")] <- "hdf.xml"
  out <- tibble::tibble(
    filename = base_only,
    url = NA_character_,
    variant_id = vid,
    year = yd$year,
    doy = yd$doy,
    tile = tile,
    status = "downloaded",
    destfile = normalizePath(fl, winslash = "/", mustWork = FALSE)
  )
  out$ext <- exts
  out$size_bytes <- NA_real_
  attr(out, "n_unknown") <- n_unknown
  out
}

# 按"行中心"裁掉极地纬度带:crop 的网格吸附在粗分辨率下会整行带回 ±90,
# 而这些行投 webmerc 时新版 GDAL 直接报 "area of interest not accepted"。
.glass_clip_webmerc_lat <- function(rr, lim = 85.0) {
  resy <- terra::res(rr)[2]
  rows <- seq_len(terra::nrow(rr))
  yy <- terra::yFromRow(rr, rows)
  keep <- which(abs(yy) <= lim)
  if (!length(keep) || length(keep) == length(rows)) return(rr)
  rmin <- min(keep); rmax <- max(keep)
  half <- resy / 2
  e <- terra::ext(terra::xmin(rr), terra::xmax(rr),
                  terra::yFromRow(rr, rmax) - half,
                  terra::yFromRow(rr, rmin) + half)
  terra::crop(rr, e)
}

# 预览配色(基础 grDevices 色板,零新依赖)
.glass_preview_palette <- function(name = c("viridis", "terrain", "heat", "green")) {
  name <- match.arg(name)
  switch(name,
    viridis = grDevices::hcl.colors(256, "viridis"),
    terrain = grDevices::terrain.colors(256, alpha = 1),
    heat    = grDevices::heat.colors(256, alpha = 1),
    green   = grDevices::hcl.colors(256, "Greens"))
}
