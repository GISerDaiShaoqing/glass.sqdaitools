#' Read GLASS HDF granules with fill/scale handling
#'
#' @description
#' Wraps `terra::rast()` for GLASS HDF-EOS granules and applies product-level
#' band cleanup in one step:
#' 1. raw fill values (e.g. 255) set to `NA`,
#' 2. the stored scale factor multiplied in,
#' 3. values outside the valid scaled range set to `NA`.
#'
#' When `product` names a registered variant, `fill`, `scale_factor` and
#' `valid_range` default to the registry values ([glass_products]); explicit
#' arguments override the registry.
#'
#' @param input One or more file paths of the **same variant and tile**
#'   (they become temporal layers of a multi-layer `SpatRaster`), or an
#'   already-open `SpatRaster`.
#' @param product Optional registry variant key, e.g. `"LAI_MODIS_250M"`.
#' @param fill Optional raw fill value (overrides the registry value).
#' @param scale_factor Optional scale factor.
#' @param valid_range Optional `c(min, max)` of the scaled data.
#' @param subds Optional sub-dataset selection passed to `terra::rast()`
#'   (needed for multi-band products such as `Ta`).
#' @param ... Passed on to `terra::rast()`.
#' @return A cleaned `SpatRaster` in data units.
#'
#' @export
#' @examples
#' \dontrun{
#' r <- glass_read("GLASS01D01.V60.A2018217.h28v05.2022013.hdf",
#'                 product = "LAI_MODIS_250M")
#' }
glass_read <- function(input, product = NULL, fill = NULL, scale_factor = NULL,
                       valid_range = NULL, subds = NULL, ...) {
  meta <- .band_meta_lookup(product)
  # terra/GDAL 读 HDF 时已自动套用 SDS 的 scale/offset(实测 LAI V6 与
  # NDVI/EVI V1 均如此),这里只管理"读入后"的值:
  # - fill 以 raw 含义给出(注册表 fill_value),乘 scale 后与读入值比对
  # - valid_range 本身就是缩放后的范围
  if (is.null(fill)) fill <- meta$fill_value
  if (is.null(scale_factor)) scale_factor <- meta$scale_factor
  if (is.null(valid_range) && is.finite(meta$valid_min) && is.finite(meta$valid_max)) {
    valid_range <- c(meta$valid_min, meta$valid_max)
  }
  fill_eff <- if (!is.null(fill) && is.finite(fill)) {
    if (!is.null(scale_factor) && is.finite(scale_factor)) fill * scale_factor else fill
  } else {
    NULL
  }

  r <- if (inherits(input, "SpatRaster")) {
    input
  } else if (is.null(subds)) {
    terra::rast(input, ...)
  } else {
    terra::rast(input, subds = subds, ...)
  }

  if (!is.null(fill_eff)) {
    r <- terra::subst(r, as.numeric(fill_eff), NA)
  }
  if (!is.null(valid_range)) {
    bad <- r < as.numeric(valid_range[1]) | r > as.numeric(valid_range[2])
    r[bad] <- NA
  }
  r
}

# 登记表条目查找;查不到时返回 NULL 集合
.band_meta_lookup <- function(product) {
  empty <- list(fill_value = NULL, scale_factor = NULL,
                valid_min = NULL, valid_max = NULL)
  if (is.null(product)) return(empty)
  rows <- tryCatch(
    glass_product_info(variant_id = product),
    error = function(e) NULL
  )
  if (is.null(rows) || nrow(rows) == 0) {
    rows <- tryCatch(glass_product_info(product = product), error = function(e) NULL)
  }
  if (is.null(rows) || nrow(rows) == 0) {
    if (!is.null(product)) {
      warning("product '", product, "' not found in the registry; no fill/scale applied",
              call. = FALSE, immediate. = TRUE)
    }
    return(empty)
  }
  if (nrow(rows) > 1) {
    rows <- if (any(rows$verified)) rows[rows$verified, , drop = FALSE]
    rows <- rows[1L, ]
  }
  list(fill_value = rows$fill_value[[1]],
       scale_factor = rows$scale_factor[[1]],
       valid_min = rows$valid_min[[1]],
       valid_max = rows$valid_max[[1]])
}

#' Merge multi-tile GLASS rasters
#'
#' Tile-aware convenience wrapper over `terra::merge()`: merges the extent
#' of several tiled granules (from the same sinusoidal source grid) into a
#' single raster.
#'
#' @param ... `SpatRaster` objects (each the result of [glass_read()]).
#' @return A merged `SpatRaster`.
#'
#' @export
glass_mosaic <- function(...) {
  parts <- list(...)
  if (length(parts) == 1L && is.list(parts[[1L]])) parts <- parts[[1L]]
  if (length(parts) < 2L) {
    glass_abort("glass_mosaic() needs two or more rasters")
  }
  do.call(terra::merge, parts)
}

#' Reproject, mask and composite GLASS rasters for a region
#'
#' @description
#' Takes granule paths (or an already-read `SpatRaster` stack), applies
#' [glass_read()] cleanup, groups granules by composite date, merges tiles
#' per date, reprojects the result to the CRS of `roi`, crops and masks, and
#' optionally collapses layers with a function (e.g. a temporal mean). This
#' is the parameterised version of the legacy `glass_process.R` script.
#'
#' @param input Granule paths of one variant, or a `SpatRaster` stack (then
#'   fill/scale handling is assumed done).
#' @param roi Region of interest (`sf`/`sfc`); its CRS is the target CRS.
#' @param target_crs Optionally override the target CRS.
#' @param res Output resolution in target-CRS units (default: automatic).
#' @param method `terra::project()` resampling method, e.g. `"cubic"`
#'   (default) or `"near"` for categorical data.
#' @param fun `"none"` (default) keeps one layer per granule date;
#'   `"mean"`, `"max"`, `"min"` or a function collapse layers.
#' @param outfile Optional GeoTIFF path to write.
#' @param product Registry variant key for [glass_read()].
#' @param ... Passed on to [glass_read()].
#'
#' @return A processed `SpatRaster`.
#'
#' @export
#' @examples
#' \dontrun{
#' files <- glass_fetch("LAI_MODIS_250M", "2018-08-01", "2018-12-31",
#'                      tiles = "h28v05", out_dir = "data/glass/lai")
#' mean_lai <- glass_process(files, roi = shanghai_sf, outfile = "lai_mean.tif")
#' }
glass_process <- function(input, roi, target_crs = NULL, res = NULL,
                          method = "cubic", fun = "none", outfile = NULL,
                          product = NULL, ...) {
  if (inherits(input, "SpatRaster")) {
    r_stack <- input
  } else {
    groups <- .glass_group_granules(input)
    per_date <- lapply(groups, function(g) {
      parts <- lapply(g$paths, function(p) glass_read(p, product = product, ...))
      kid <- if (length(parts) == 1L) parts[[1L]] else do.call(terra::merge, parts)
      names(kid) <- g$label
      kid
    })
    # per_date 是单层 SpatRaster 列表;terra 未导出 c,经由 base::c 的 S3 派发
    r_stack <- do.call(c, per_date)
  }

  if (is.null(roi)) {
    glass_abort("`roi` is required for cropping/masking")
  }
  if (is.null(target_crs)) {
    tgt <- sf::st_crs(roi)
  } else {
    tgt <- sf::st_crs(target_crs)
  }
  if (is.na(tgt)) glass_abort("target CRS is unknown")
  roi_v <- terra::vect(sf::st_transform(roi, tgt))

  # terra::project 接受 "epsg:NNN" / proj4 / WKT 字符串
  tgt_text <- if (!is.na(tgt$epsg)) paste0("epsg:", tgt$epsg) else tgt$wkt
  r_pj <- terra::project(r_stack, tgt_text, method = method, res = res)
  r_pj <- terra::crop(r_pj, roi_v)
  r_pj <- terra::mask(r_pj, roi_v)

  r_out <- .glass_collapse_fun(r_pj, fun)
  if (!is.null(outfile)) {
    terra::writeRaster(r_out, outfile, overwrite = TRUE,
                       gdal = list(driver = "GTiff"))
  }
  r_out
}

# 折叠 layers 的调度
.glass_collapse_fun <- function(r, fun) {
  if (is.null(fun) || identical(fun, "none")) return(r)
  if (is.character(fun)) {
    switch(fun,
      mean = terra::app(r, mean, na.rm = TRUE),
      max  = terra::app(r, max, na.rm = TRUE),
      min  = terra::app(r, min, na.rm = TRUE),
      glass_abort("fun must be 'none', 'mean', 'max', 'min' or a function"))
  } else if (is.function(fun)) {
    terra::app(r, fun)
  } else {
    glass_abort("fun must be 'none', 'mean', 'max', 'min' or a function")
  }
}

# 按文件名里的 A<year><doy> 与 h<v> 解析并按合成日期分组
# 返回 list(label = ~, date = Date, tile = ~, paths = ~)
.glass_group_granules <- function(paths) {
  base <- basename(paths)
  m_date <- regmatches(base, regexec("\\.A([0-9]{4})([0-9]{3})\\.", base))
  m_tile <- regmatches(base, regexpr("h[0-9]{2}v[0-9]{2}", base))
  ok <- unlist(lapply(m_date, function(z) length(z) >= 3))
  if (any(!ok)) {
    glass_abort(paste0("File name(s) without the '.A<year><doy>.' GLASS pattern: ",
                       paste(shQuote(base[!ok]), collapse = ", ")))
  }
  year <- vapply(m_date, function(z) as.integer(z[2]), integer(1))
  doy <- vapply(m_date, function(z) as.integer(z[3]), integer(1))
  tile <- if (length(m_tile) == length(base)) m_tile else rep(NA_character_, length(base))

  df <- data.frame(path = paths, base = base, year = year, doy = doy,
                   tile = tile, stringsAsFactors = FALSE)
  df <- df[order(df$year, df$doy, df$tile), , drop = FALSE]
  out <- list()
  key <- paste0(df$year, "_", sprintf("%03d", df$doy))
  for (k in unique(key)) {
    i <- key == k
    y <- df$year[i][1]
    d <- df$doy[i][1]
    out[[length(out) + 1]] <- list(
      label = paste0("A", y, sprintf("%03d", d)),
      date = as.Date(strptime(paste0(y, "-", d), "%Y-%j")),
      tile = df$tile[i],
      paths = df$path[i]
    )
  }
  out
}
