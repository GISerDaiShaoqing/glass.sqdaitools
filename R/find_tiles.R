# 瓦片边长(米),36 x 18 瓦片恰好覆盖全球
.GLASS_TILE_SIZE <- 1111950.51966667

#' Map a region of interest onto GLASS sinusoidal tiles
#'
#' @description
#' GLASS tiled products use the classic MODIS sinusoidal `h`/`v` grid
#' (`h<h>v<v>` fragments in file names). These functions rebuild the exact
#' tile polygons in the sinusoidal projection, transform them to WGS84 and
#' intersect them with your region of interest, returning the tiles you need
#' to download.
#'
#' @param roi A spatial vector object (`sf`/`sfc`, any CRS).
#' @param lon_min,lon_max,lat_min,lat_max WGS84 bounding box.
#'
#' @return An `sf` object (rows = tiles) with columns `h`, `v`,
#'   `lon_min`, `lon_max`, `lat_min`, `lat_max`, `valid` and the tile
#'   `geometry` in WGS84.
#'
#' @export
#' @examples
#' glass_tiles_for_bbox(120.8, 30.6, 122.2, 31.9)  # Shanghai
glass_tiles_for_bbox <- function(lon_min, lat_min, lon_max, lat_max) {
  if (any(c(lon_min, lat_min, lon_max, lat_max) < -180) ||
      any(c(lon_min, lat_min, lon_max, lat_max) > 180)) {
    glass_abort("Invalid lon/lat bounds")
  }
  if (lon_min > lon_max || lat_min > lat_max) {
    glass_abort("Bounds must satisfy lon_min <= lon_max and lat_min <= lat_max")
  }
  roi <- sf::st_as_sfc(sf::st_bbox(
    c(xmin = lon_min, ymin = lat_min, xmax = lon_max, ymax = lat_max),
    crs = 4326L
  ))
  .tiles_for_geometry(roi)
}

#' @rdname glass_tiles_for_bbox
#' @export
glass_tiles_for_sf <- function(roi) {
  geom <- sf::st_geometry(roi)
  if (length(geom) == 0) {
    glass_abort("`roi` must contain at least one geometry")
  }
  if (is.na(sf::st_crs(geom))) {
    glass_abort("`roi` has no CRS; set one before calling")
  }
  if (sf::st_crs(geom) != sf::st_crs(4326L)) {
    geom <- sf::st_transform(geom, 4326L)
  }
  .tiles_for_geometry(geom)
}

# 工作函数:几何对象 -> 已用正弦投影求候选瓦片 -> 精确求交
.tiles_for_geometry <- function(geom) {
  crs_sinu <- .glass_crs_sinu()
  bb <- sf::st_bbox(sf::st_transform(geom, crs_sinu))
  tsize <- .GLASS_TILE_SIZE

  h_lo <- max(0L, floor(bb["xmin"] / tsize) + 18L)
  h_hi <- min(35L, floor(bb["xmax"] / tsize) + 18L)
  v_lo <- max(0L, 8L - floor(bb["ymax"] / tsize))
  v_hi <- min(17L, 8L - floor(bb["ymin"] / tsize))

  hvs <- expand.grid(h = h_lo:h_hi, v = v_lo:v_hi)
  if (nrow(hvs) == 0L) glass_abort("No tiles exist for the given extent")

  polys <- lapply(seq_len(nrow(hvs)), function(i) .tile_polygon(hvs$h[i], hvs$v[i]))
  cand <- sf::st_sf(
    h = hvs$h, v = hvs$v,
    geometry = do.call(c, polys)
  )

  hit <- sf::st_intersects(cand, geom, sparse = FALSE, prepared = TRUE)
  sel <- apply(hit, 1, any)
  out <- cand[sel, , drop = FALSE]
  if (nrow(out) == 0L) {
    glass_abort("The ROI intersects no GLASS tile (check lon/lat range)")
  }

  # 每个瓦片的经纬度外接矩形
  bounds <- do.call(rbind, lapply(sf::st_geometry(out), .poly_bbox))
  out$lon_min <- bounds[, 1]
  out$lon_max <- bounds[, 2]
  out$lat_min <- bounds[, 3]
  out$lat_max <- bounds[, 4]

  # 有效瓦片集合与内置 glass_tiles 数据集对照(极角瓦片无效)
  reg <- .read_pkg_data("glass_tiles")
  key <- paste0(out$h, "_", out$v)
  out$valid <- key %in% paste0(reg$h, "_", reg$v)[reg$valid]
  out[, c("h", "v", "lon_min", "lon_max", "lat_min", "lat_max", "valid", "geometry")]
}

# 多边形的外接经纬度矩形
.poly_bbox <- function(g) {
  pts <- sf::st_coordinates(g)
  c(min(pts[, "X"]), max(pts[, "X"]), min(pts[, "Y"]), max(pts[, "Y"]))
}

# 重建一个瓦片(h, v)的 WGS84 精确多边形
# 瓦片在正弦投影空间为规则方格:x = (h-18)*tile .. (h-17)*tile
#                           y = (8-v)*tile .. (9-v)*tile
.tile_polygon <- function(h, v) {
  tsize <- .GLASS_TILE_SIZE
  x0 <- (h - 18L) * tsize
  y0 <- (9L - v) * tsize
  ring <- matrix(c(
    x0,          y0,
    x0 + tsize,  y0,
    x0 + tsize,  y0 - tsize,
    x0,          y0 - tsize,
    x0,          y0
  ), ncol = 2, byrow = TRUE)
  g <- sf::st_sfc(sf::st_polygon(list(ring)), crs = .glass_crs_sinu())
  sf::st_transform(g, 4326L)
}

.GLASS_TILE_SIZE <- 1111950.51966667

# 与 GLASS/MODIS HDF 文件一致的正弦投影(CRS)
.glass_crs_sinu <- function() {
  sf::st_crs("+proj=sinu +lon_0=0 +x_0=0 +y_0=0 +a=6371007.181 +b=6371007.181 +units=m +no_defs")
}