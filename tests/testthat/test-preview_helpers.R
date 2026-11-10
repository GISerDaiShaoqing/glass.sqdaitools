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

test_that("扫描导入:变体识别(HDF 代码/HiGLASS/TPSCE/AWGF)+年/DOY 解析 + 未知剔除", {
  skip_if_not_installed("terra")
  d <- file.path(tempdir(), paste0("scanimp_", as.integer(Sys.time())))
  dir.create(file.path(d, "sub"), recursive = TRUE, showWarnings = FALSE)
  fl <- c(
    file.path(d, "GLASS01D01.V60.A2018217.h28v05.2022013.hdf"),
    file.path(d, "sub", "HiGLASS_LS20_n045e120_2018_v01_LAI.tif"),
    file.path(d, "Combined_TPSCE_1981213.dat"),
    file.path(d, "global_hourly_all_sky_lst_2011001.nc"),
    file.path(d, "GLASS13J01.201001.V10.2023068.hdf"),
    file.path(d, "readme.txt"),
    file.path(d, "image_preview.jpg")
  )
  for (f in fl[1:5]) writeLines("x", f)
  writeLines("x", fl[6]); writeLines("x", fl[7])
  m <- .glass_preview_groups  # 形状 sanity 后走 scan
  msc <- .glass_scan_import(d)
  expect_false(nrow(msc) == 0L)
  expect_equal(nrow(msc), 5L)
  expect_true(attr(msc, "n_unknown") == 0L)
  id <- setNames(msc$variant_id, msc$filename)
  expect_equal(unname(id[basename(fl[1])]), "LAI_MODIS_250M")
  expect_equal(unname(id[basename(fl[2])]), "LAI_HR_LAI_V01")
  expect_equal(unname(id[basename(fl[3])]), "TPSCE_AVHRR")
  expect_equal(unname(id[basename(fl[4])]), "AWGF_LST_GHA-LST")
  # 年/年月/年度解析
  y <- setNames(msc$year, msc$filename)
  dd <- setNames(msc$doy, msc$filename)
  expect_equal(unname(y[basename(fl[1])]), 2018L)
  expect_equal(unname(dd[basename(fl[1])]), 217L)
  expect_equal(unname(y[basename(fl[2])]), 2018L)
  expect_true(unname(is.na(dd[basename(fl[2])]))[1])       # _2018_ 年度
  expect_equal(unname(y[basename(fl[3])]), 1981L)
  expect_equal(unname(dd[basename(fl[3])]), 213L)
  expect_equal(unname(y[basename(fl[4])]), 2011L)
  expect_equal(unname(dd[basename(fl[4])]), 1L)
  # 月码文件:2010-01 -> doy 1
  expect_equal(unname(y[basename(fl[5])]), 2010L)
  expect_equal(unname(dd[basename(fl[5])]), 1L)
  # 分组样式:HiGLASS 走 n045e120 瓦片名
  g <- .glass_preview_groups(msc)
  expect_true(any(grepl("n045e120", g$label)))
  expect_true(any(grepl("2018 年度", g$label)))
  # 未知变体文件:剔除并计数(专用空目录,避免误扫共享 tempdir 的其它文件)
  d2 <- file.path(tempdir(), paste0("unknown_", format(Sys.time(), "%Y%m%d%H%M%S")))
  dir.create(d2, showWarnings = FALSE)
  f7 <- file.path(d2, "SomeOther.Tool.2018.v1.tif")
  writeLines("x", f7)
  m2 <- .glass_scan_import(d2, max_files = 100L)
  expect_equal(nrow(m2), 0L)
  expect_equal(attr(m2, "n_unknown"), 1L)
  unlink(d2, recursive = TRUE)
  unlink(d, recursive = TRUE)
})

test_that("配色板:四个候选均可生成 256 色,非法名被 match.arg 拒", {
  for (nm in c("viridis", "terrain", "heat", "green")) {
    p <- .glass_preview_palette(nm)
    expect_length(p, 256L)
  }
  expect_error(.glass_preview_palette("name不行的"))
})
