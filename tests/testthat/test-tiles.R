test_that("Shanghai bbox resolves to h28v05", {
  t <- glass_tiles_for_bbox(120.8, 30.6, 122.2, 31.9)
  expect_true(nrow(t) >= 1L)
  expect_true("h28v05" %in% sprintf("h%02dv%02d", t$h, t$v))
  expect_s3_class(t, "sf")
  expect_true("geometry" %in% names(t))
})

test_that("point ROI returns exactly one tile", {
  p <- sf::st_sfc(sf::st_point(c(121.47, 31.23)), crs = 4326)
  t <- glass_tiles_for_sf(p)
  expect_equal(nrow(t), 1L)
  expect_equal(t$h, 28L)
  expect_equal(t$v, 5L)
})

test_that("formula tile bounds agree with the bundled glass_tiles table", {
  reg <- glass_tiles
  reg <- reg[reg$valid, ]
  # 旧查找表在极区行是扇形小条、日界线列有 ±180 归一化差异,
  # 单元测试只对中纬度、不跨日界线的常规瓦片做对照
  ok_lat <- reg$lat_min >= 45 & reg$lat_max <= 75
  ok_lon <- pmax(abs(reg$lon_min), abs(reg$lon_max)) < 178
  reg <- reg[ok_lat & ok_lon, , drop = FALSE]
  set.seed(1)
  k <- sample(seq_len(nrow(reg)), 12L)
  for (i in k) {
    g <- .tile_polygon(reg$h[i], reg$v[i])
    bb <- .poly_bbox(g)
    # 数据集保留 4 位小数,允许 ~0.05 度误差
    expect_lt(abs(bb[1] - reg$lon_min[i]), 0.08)
    expect_lt(abs(bb[2] - reg$lon_max[i]), 0.08)
    expect_lt(abs(bb[3] - reg$lat_min[i]), 0.08)
    expect_lt(abs(bb[4] - reg$lat_max[i]), 0.08)
  }
})

test_that("glass_tiles dataset keeps the invalid corner tiles", {
  # tsv 源里 648 行中 188 行为投影足迹外(-999/-99 占位)
  expect_equal(sum(!glass_tiles$valid), 188L)
  expect_equal(sum(glass_tiles$valid), 460L)
  expect_true(all(is.na(glass_tiles$lon_min[!glass_tiles$valid])))
})

test_that("bad bounds abort", {
  expect_error(glass_tiles_for_bbox(10, 0, 5, 10), "lon_min")
  expect_error(glass_tiles_for_bbox(-200, 0, -150, 10), "Invalid lon/lat")
})
