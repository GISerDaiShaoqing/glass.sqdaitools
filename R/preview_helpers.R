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
          nzchar(m$destfile) & file.exists(m$destfile)
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

# 预览成图管线:glass_read(登记表自填 fill/scale/valid_range) -> 多瓦片合并
#   -> ROI 外扩 0.5° 裁剪 -> 重投影 EPSG:4326 并按 .glass_preview_res 粗化。
# 返回单层 SpatRaster(超过一层 SDS 仅取第一层,帮助文本需注明)。
.glass_preview_raster <- function(destfiles, variant_id, roi_bbox = NULL) {
  ok <- file.exists(destfiles)
  fl <- destfiles[ok]
  if (!length(fl)) {
    glass_abort("no local granules to preview - out_dir changed or files moved")
  }
  rlist <- lapply(fl, function(f) {
    r1 <- glass_read(f, product = variant_id)
    if (!is.null(roi_bbox) &&
        all(c("xmin", "xmax", "ymin", "ymax") %in% names(roi_bbox))) {
      e <- terra::ext(roi_bbox[["xmin"]] - 0.5, roi_bbox[["xmax"]] + 0.5,
                      roi_bbox[["ymin"]] - 0.5, roi_bbox[["ymax"]] + 0.5)
      r1 <- terra::crop(r1, e)
    }
    r1
  })
  rr <- if (length(rlist) > 1L) glass_mosaic(rlist) else rlist[[1]]
  if (terra::nlyr(rr) > 1L) rr <- rr[[1]]
  bb2 <- c(xmin = terra::xmin(rr), xmax = terra::xmax(rr),
           ymin = terra::ymin(rr), ymax = terra::ymax(rr))
  rr <- terra::project(rr, "epsg:4326", res = .glass_preview_res(bb2),
                       method = "bilinear")
  rr
}

# 预览下采样分辨率(度/像素):按显示跨度和目标像素量估算
.glass_preview_res <- function(bbox, target_px = 7e5) {
  if (is.null(bbox) || !all(c("xmin", "xmax", "ymin", "ymax") %in% names(bbox))) {
    return(0.05)
  }
  dx <- max(0.05, as.numeric(bbox[["xmax"]]) - as.numeric(bbox[["xmin"]]))
  dy <- max(0.05, as.numeric(bbox[["ymax"]]) - as.numeric(bbox[["ymin"]]))
  r <- sqrt((dx * dy) / max(target_px, 1e4))
  max(r, 0.0025)    # 细过 0.0025°(约 250 m)不再细化:主 LUT 开销失控
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
