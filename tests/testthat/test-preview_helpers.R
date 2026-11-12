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

test_that("layers 枚举:双层 GeoTIFF 按图层名,单层/坏文件回退", {
  skip_if_not_installed("terra")
  d <- file.path(tempdir(), paste0("lyrs_", format(Sys.time(), "%H%M%S")))
  dir.create(d, showWarnings = FALSE)
  on.exit(unlink(d, recursive = TRUE), add = TRUE)
  f <- file.path(d, "two.tif")
  r <- terra::rast(terra::ext(0, 2, 0, 2), nrows = 4, ncols = 4, nlyr = 2)
  terra::values(r) <- c(rep(1, 16), rep(3, 16))
  names(r) <- c("alpha", "beta")
  terra::writeRaster(r, f, overwrite = TRUE, filetype = "GTiff")
  ldf <- .glass_preview_layers(f)
  expect_equal(nrow(ldf), 2L)
  expect_equal(ldf$label, c("alpha", "beta"))
  expect_true(all(is.na(ldf$subds)))
  expect_equal(ldf$layer, 1:2)
  # 单层 GeoTIFF:回退单行
  f1 <- file.path(d, "one.tif")
  r1 <- terra::rast(terra::ext(0, 2, 0, 2), nrows = 4, ncols = 4)
  terra::values(r1) <- rep(2, 16)
  terra::writeRaster(r1, f1, overwrite = TRUE, filetype = "GTiff")
  l1 <- .glass_preview_layers(f1)
  expect_equal(nrow(l1), 1L)
  # 无法解析的文件:回退单行,不抛错
  fbad <- file.path(d, "bad.tif")
  writeLines("not a raster", fbad)
  lb <- .glass_preview_layers(fbad)
  expect_equal(nrow(lb), 1L)
})

test_that("管线 layer=:双层 GeoTIFF 取指定层(product=NULL 无元数据介入)", {
  skip_if_not_installed("terra")
  d <- file.path(tempdir(), paste0("pick_", format(Sys.time(), "%H%M%S")))
  dir.create(d, showWarnings = FALSE)
  on.exit(unlink(d, recursive = TRUE), add = TRUE)
  f <- file.path(d, "two.tif")
  r <- terra::rast(terra::ext(0, 2, 0, 2), nrows = 4, ncols = 4, nlyr = 2)
  terra::values(r) <- c(rep(1, 16), rep(3, 16))
  names(r) <- c("alpha", "beta")
  terra::writeRaster(r, f, overwrite = TRUE, filetype = "GTiff")
  m1 <- terra::global(suppressWarnings(.glass_preview_raster(f, NULL, to_merc = FALSE,
                                                         layer = 1)),
                      "mean", na.rm = TRUE)[[1]][1]
  m2 <- terra::global(suppressWarnings(.glass_preview_raster(f, NULL, to_merc = FALSE,
                                                         layer = 2)),
                      "mean", na.rm = TRUE)[[1]][1]
  expect_equal(m1, 1)
  expect_equal(m2, 3)
  # 越界 layer 安全回退到可用层
  mo <- terra::global(suppressWarnings(.glass_preview_raster(f, NULL, to_merc = FALSE,
                                                         layer = 99)),
                      "mean", na.rm = TRUE)[[1]][1]
  expect_equal(mo, 3)
})

test_that("netCDF 单变量时间层:枚举与按层选取(多变量 SDS 由真机样本验证)", {
  skip_if_not_installed("terra")
  d <- file.path(tempdir(), paste0("nc_", format(Sys.time(), "%H%M%S")))
  dir.create(d, showWarnings = FALSE)
  on.exit(unlink(d, recursive = TRUE), add = TRUE)
  fnc <- file.path(d, "two.nc")
  nc_ok <- tryCatch({
    r <- terra::rast(terra::ext(0, 2, 0, 2), nrows = 4, ncols = 4, nlyr = 2)
    terra::values(r) <- c(rep(1, 16), rep(3, 16))
    names(r) <- c("va", "vb")
    terra::writeCDF(r, fnc, overwrite = TRUE)
    file.exists(fnc)
  }, error = function(e) FALSE)
  skip_if_not(isTRUE(nc_ok), "terra lacks netCDF write support")
  # terra 写出的 nc 是单变量 + 时间层:describe(sds=TRUE) 报 no subdatasets,
  # 枚举走多图层分支(subds 全 NA),标签与 rast(fnc) 图层名一致
  ldf <- .glass_preview_layers(fnc)
  expect_equal(nrow(ldf), 2L)
  expect_setequal(ldf$label, terra::names(terra::rast(fnc)))
  expect_true(all(is.na(ldf$subds)))
  # subds 序号传了也安全(sds() 无子数据集时回退整文件,再按 layer 选层)
  m1 <- terra::global(suppressWarnings(.glass_preview_raster(fnc, NULL,
                                    to_merc = FALSE, subds = 1, layer = 1)),
                      "mean", na.rm = TRUE)[[1]][1]
  m2 <- terra::global(suppressWarnings(.glass_preview_raster(fnc, NULL,
                                    to_merc = FALSE, layer = 2)),
                      "mean", na.rm = TRUE)[[1]][1]
  expect_equal(m1, 1)
  expect_equal(m2, 3)
})

test_that("all-NA 守卫:注册表元数据洗空时退回原始值读取", {
  skip_if_not_installed("terra")
  d <- file.path(tempdir(), paste0("guard_", format(Sys.time(), "%H%M%S")))
  dir.create(d, showWarnings = FALSE)
  on.exit(unlink(d, recursive = TRUE), add = TRUE)
  # LAI_MODIS_250M:raw fill 255 × scale 0.1 = 25.5 -> 清洗后整层 NA
  f <- file.path(d, "fill255.tif")
  r <- terra::rast(terra::ext(0, 2, 0, 2), nrows = 4, ncols = 4)
  terra::values(r) <- rep(25.5, 16)
  terra::writeRaster(r, f, overwrite = TRUE, filetype = "GTiff")
  expect_message(rr <- suppressWarnings(
    .glass_preview_raster(f, "LAI_MODIS_250M", to_merc = FALSE)),
    "raw values")
  expect_true(terra::global(rr, function(x) sum(!is.na(x)))[[1]][1] > 0)
})

test_that("domain:minmax 与 p2_98 分位,空/退化输入回退 c(0,1)", {
  v <- c(stats::rnorm(200, 10, 1), 1e6)  # 带离群值
  d1 <- .glass_preview_domain(v, "minmax")
  d2 <- .glass_preview_domain(v, "p2_98")
  expect_equal(d1, c(min(v), max(v)))
  expect_true(d2[2] < d1[2] / 10)
  expect_true(d2[2] > 10 && d2[2] < 14)
  expect_equal(.glass_preview_domain(c(NA, NA), "p2_98"), c(0, 1))
  expect_equal(.glass_preview_domain(numeric(0), "minmax"), c(0, 1))
  expect_error(.glass_preview_domain(v, "不存在的"))
})

test_that("分组剔除 .hdf.xml 元数据伴随文件(fetch 会连它一起下载)", {
  d <- file.path(tempdir(), paste0("xml_", format(Sys.time(), "%H%M%S")))
  dir.create(d, showWarnings = FALSE)
  on.exit(unlink(d, recursive = TRUE), add = TRUE)
  fh <- file.path(d, "GLASS14D01.V10.A2024297.h28v06.2026057.hdf")
  fx <- paste0(fh, ".xml")
  writeLines("x", fh); writeLines("<meta/>", fx)
  m <- tibble::tibble(
    filename = basename(c(fh, fx)),
    variant_id = c("GLASS14D01_V10", "GLASS14D01_V10"),
    year = c(2024L, 2024L), doy = c(297L, 297L),
    tile = c("h28v06", "h28v06"),
    status = c("downloaded", "downloaded"),
    destfile = c(fh, fx),
    size_bytes = c(1, 1)
  )
  g <- .glass_preview_groups(m)
  expect_equal(nrow(g), 1L)
  expect_equal(g$n_files[1], 1L)             # xml 伴随文件不计入
  expect_setequal(g$destfiles[[1]], fh)
})

test_that("管线跳过无法读取的粒(伴随/损坏),用好粒成图;全败才中止", {
  skip_if_not_installed("terra")
  d <- file.path(tempdir(), paste0("skip_", format(Sys.time(), "%H%M%S")))
  dir.create(d, showWarnings = FALSE)
  on.exit(unlink(d, recursive = TRUE), add = TRUE)
  fbad <- file.path(d, "GLASS14D01.V10.A2024297.h28v06.2026057.hdf.xml")
  writeLines("<metadata/>", fbad)
  fg <- file.path(d, "good.tif")
  r <- terra::rast(terra::ext(0, 2, 0, 2), nrows = 4, ncols = 4)
  terra::values(r) <- rep(3, 16)
  terra::writeRaster(r, fg, overwrite = TRUE, filetype = "GTiff")
  # 坏粒 + 好粒:自动跳过坏粒,成图
  expect_message(
    rr <- suppressWarnings(.glass_preview_raster(c(fbad, fg), NULL, to_merc = FALSE)),
    "skipping")
  expect_equal(terra::global(rr, "mean", na.rm = TRUE)[[1]][1], 3)
  # 全是坏粒:明确中止
  expect_error(suppressWarnings(.glass_preview_raster(c(fbad), NULL, to_merc = FALSE)),
               "no readable granules")
})
