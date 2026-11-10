# 地图叠加预览的纯逻辑单测(不联网、不启动 Shiny)

mk_manifest <- function() {
  d <- tempdir()
  f1 <- file.path(d, "GLASS01D01.V60.A2018217.h28v05.2022013.hdf")
  f2 <- file.path(d, "GLASS01D01.V60.A2018217.h27v05.2022013.hdf")
  f3 <- file.path(d, "HiGLASS_LS20_n045e120_2018_v01_LAI.tif")
  writeLines("x", f1); writeLines("x", f2); writeLines("x", f3)
  tibble::tibble(
    filename = basename(c(f1, f2, f3, f1, f3)),
    variant_id = c("LAI_MODIS_250M", "LAI_MODIS_250M", "LAI_HR_LAI_V01",
                   "LAI_MODIS_250M", "LAI_HR_LAI_V01"),
    year = c(2018, 2018, 2018, 2018, 2018),
    doy  = c(217, 217, NA, 217, NA),
    tile = c("h28v05", "h27v05", "n045e120", "h28v05", "n045e120"),
    status = c("downloaded", "downloaded", "downloaded", "failed",
               "downloaded"),
    destfile = c(f1, f2, f3, f1, file.path(d, "missing.tif")),
    size_bytes = c(1, 1, 1, 1, 1)
  )
}

test_that("分组:只收下载成功且本地存在的行;failed/缺文件行被剔", {
  m <- mk_manifest()
  g <- .glass_preview_groups(m)
  expect_false(is.null(g))
  expect_equal(nrow(g), 2L)
  keys <- g$group_key
  expect_true(any(grepl("^LAI_MODIS_250M\\|2018\\|217$", keys)))
  expect_true(any(grepl("^LAI_HR_LAI_V01\\|2018\\|-1$", keys)))
  # LAI 组剩 2 瓦片(h28v05+h27v05):failed 的第一条 destfile 引用同文件,不应计入
  lai <- g[grepl("LAI_MODIS", g$group_key), ]
  expect_equal(lai$n_files, 2L)
  expect_setequal(lai$destfiles[[1]], c(
    m$destfile[1], m$destfile[2]))
  # 年度组标签含“年度”
  hr <- g[grepl("LAI_HR", g$group_key), ]
  expect_match(hr$label, "年度")
  expect_true(grepl("n045e120", hr$label))
})

test_that("无 destfile / 空清单 -> 0 行", {
  expect_equal(nrow(.glass_preview_groups(NULL)), 0L)
  m0 <- tibble::tibble()
  expect_equal(nrow(.glass_preview_groups(m0)), 0L)
  m1 <- tibble::tibble(filename = "a.hdf", status = "downloaded")  # 无 destfile
  expect_equal(nrow(.glass_preview_groups(m1)), 0L)
})

test_that("预览分辨率:小框触下限、全球框压到目标量级", {
  small <- .glass_preview_res(c(xmin = 121.0, xmax = 121.4,
                                ymin = 31.0, ymax = 31.3))
  expect_equal(small, 0.0025)
  glob <- .glass_preview_res(c(xmin = -180, xmax = 180, ymin = -90, ymax = 90))
  expect_true(glob > 0.18 && glob < 0.45)
  mid <- .glass_preview_res(c(xmin = 110, xmax = 122, ymin = 20, ymax = 32))
  expect_true(mid >= 0.0025 && mid <= 0.1)
  expect_equal(.glass_preview_res(NULL), 0.05)
})

test_that("预览管线:双瓦片 GeoTIFF 合并 + 4326 粗化(全离线)", {
  skip_if_not_installed("terra")
  d <- tempdir()
  mk <- function(x0, y0) {
    r <- terra::rast(
      terra::ext(x0 - 1, x0 + 1, y0 - 1, y0 + 1),
      nlyr = 1L, crs = "epsg:4326")
    terra::values(r) <- matrix(stats::runif(terra::ncell(r), 1, 100),
                               terra::ncell(r), 1)
    f <- file.path(d, sprintf("fake_%.2f_%.2f.tif", x0, y0))
    terra::writeRaster(r, f, overwrite = TRUE)
    f
  }
  f1 <- mk(120.5, 44.5); f2 <- mk(121.5, 44.5)
  rr <- .glass_preview_raster(c(f1, f2), "LST_MODIS_Daily",
                              roi_bbox = c(xmin = 120.2, xmax = 121.8,
                                           ymin = 44.1, ymax = 44.9))
  expect_s4_class(rr, "SpatRaster")
  expect_equal(terra::nlyr(rr), 1L)
  # raster 已投影到 4326,且经粗化后像素量不至于爆内存
  expect_true(terra::ncell(rr) < 3e6)
  expect_true(terra::xres(rr) >= 0.0025)
  # ROI 外扩 0.5 度的裁剪效果:范围不越过 [xlim-1, xlim+1]+0.5
  expect_true(terra::xmax(rr) <= 122.5)
  # 缺失本地文件 -> abort
  expect_error(.glass_preview_raster("missing_in_temp.tif",
                                     "LST_MODIS_Daily"), "no local granules")
})

test_that("配色板:四个候选均可生成 256 色,非法名被 match.arg 拒", {
  for (nm in c("viridis", "terrain", "heat", "green")) {
    p <- .glass_preview_palette(nm)
    expect_length(p, 256L)
  }
  expect_error(.glass_preview_palette("name不行的"))
})
