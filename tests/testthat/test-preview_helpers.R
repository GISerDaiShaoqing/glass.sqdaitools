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

test_that("配色板:四个候选均可生成 256 色,非法名被 match.arg 拒", {
  for (nm in c("viridis", "terrain", "heat", "green")) {
    p <- .glass_preview_palette(nm)
    expect_length(p, 256L)
  }
  expect_error(.glass_preview_palette("name不行的"))
})

test_that("to_merc=TRUE:输出 webmerc、像素量受控(leaflet project=FALSE 配套)", {
  skip_if_not_installed("terra")
  d <- file.path(tempdir(), paste0("merc_", format(Sys.time(), "%H%M%S")))
  dir.create(d, showWarnings = FALSE)
  on.exit(unlink(d, recursive = TRUE), add = TRUE)
  f <- file.path(d, "cmg.tif")
  r <- terra::rast(terra::ext(0, 360, -90, 90), nlyr = 1L, crs = "epsg:4326")
  terra::values(r) <- stats::runif(terra::ncell(r), 1, 10)
  terra::writeRaster(r, f, overwrite = TRUE, filetype = "GTiff")
  rr <- suppressWarnings(.glass_preview_raster(f, "Albedo_ABI_0_05D",
                                               to_merc = TRUE))
  expect_s4_class(rr, "SpatRaster")
  expect_true(terra::ncell(rr) <= 1e6)
  expect_true(terra::xmin(rr) >= -20037510 && terra::xmax(rr) <= 20037510)
  expect_true(terra::ymin(rr) >= -20037510 && terra::ymax(rr) <= 20037510)
  expect_true(all(terra::res(rr) > 0))
})
