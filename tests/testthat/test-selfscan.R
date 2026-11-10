# cadence-NA 自检分支的纯逻辑单测(不联网)

test_that("复合码 -> Date:正常 doy / 月刊码 / 非法值", {
  cs <- .glass_code_start(as.integer(c("2018213", "2018193", "2012001")), month_mode = FALSE)
  expect_equal(cs, as.Date(c("2018-08-01", "2018-07-12", "2012-01-01")))
  cm <- .glass_code_start(as.integer(c("201001", "201002")), month_mode = TRUE)
  expect_equal(cm, as.Date(c("2010-01-01", "2010-02-01")))
  cbad <- .glass_code_start(as.integer(c("201013")), month_mode = TRUE)
  expect_true(is.na(cbad))
})

test_that("年度单文件 token(_2018_)与三位段 0 的 Date 解读", {
  ca <- .glass_code_start(as.integer(c("2018000", "2019000")), month_mode = FALSE)
  expect_equal(ca, as.Date(c("2018-01-01", "2019-01-01")))
  info <- list(verified = TRUE, code = NA_character_)
  files <- c("HiGLASS_LS20_n045e120_2018_v01_LAI.tif",
             "HiGLASS_LS20_n045e120_2019_v01_LAI.tif")
  m <- .glass_year_manifest("X_HR", info, files, "https://x/n045e120/", tile_ids = NULL)
  expect_equal(m$year, c(2018L, 2019L))
  expect_equal(m$start, as.Date(c("2018-01-01", "2019-01-01")))
  expect_equal(m$doy, c(1L, 1L))
  expect_equal(m$ext, c("tif", "tif"))
  fspan <- .glass_year_filter(m, as.Date("2018-06-01"), as.Date("2019-03-01"), "span")
  expect_equal(nrow(fspan), 2L)
  fstart <- .glass_year_filter(m, as.Date("2019-01-01"), as.Date("2019-03-01"), "start")
  expect_equal(fstart$year, 2019L)
})

test_that("bbox -> 1° 分格 id 列表(含负经/纬 defensively)", {
  ids <- .glass_bbox_geotiles(c(xmin = 120.4, ymin = 44.6, xmax = 121.7, ymax = 45.2))
  expect_setequal(ids, c("n044e120", "n044e121", "n045e120", "n045e121"))
  ids2 <- .glass_bbox_geotiles(c(xmin = -1.2, ymin = -0.5, xmax = 0.2, ymax = 0.3))
  # floor(-0.5) = -1 -> 南向格 s001;floor(0.3) = 0 -> 北向格 n000
  expect_setequal(ids2, c("s001w002", "s001w001", "s001e000",
                          "n000w002", "n000w001", "n000e000"))
  expect_null(.glass_bbox_geotiles(NULL))
})

test_that("年文件夹清单:A 头复合码、jpg/非本产品/无扩展名剔除,prefix 进 url", {
  info <- list(verified = TRUE, code = "GLASS06G01")
  files <- c(
    "GLASS06G01.V42.A2018193.2019009.hdf",
    "GLASS06G01.V42.A2018193.2019009.hdf.xml",
    "GLASS06G01.V42.A2018201.2019009.hdf",
    "GLASS06G01.V42.A2018209.2019009.jpg",
    "OtherPub.V42.A2018217.2019009.hdf",
    "readme"
  )
  m <- .glass_year_manifest("X_TEST", info, files, "https://x/2018/", tile_ids = NULL)
  expect_false(is.null(m))
  expect_equal(nrow(m), 3L)
  expect_setequal(m$ext, c("hdf", "hdf", "hdf.xml"))
  expect_true(all(startsWith(m$url, "https://x/2018/")))
  # A2018193 = 2018-07-12(doy 193);A2018201 = 2018-07-20(doy 201)
  expect_setequal(m$filename, c(
    "GLASS06G01.V42.A2018193.2019009.hdf",
    "GLASS06G01.V42.A2018193.2019009.hdf.xml",
    "GLASS06G01.V42.A2018201.2019009.hdf"))
  expect_true(all(m$doy %in% c(193L, 201L)))
  expect_equal(unique(m$year), 2018L)
  expect_false(any(is.na(m$start)))
})

test_that("月码(NDVI .201001.)与尾部年码(TPSCE)可解析,start 正确", {
  f1 <- c("GLASS13J01.201001.V10.2023068.hdf", "GLASS13J01.201002.V10.2023068.hdf")
  m1 <- .glass_year_manifest("X_TEST", list(verified = TRUE, code = "GLASS13J01"),
                             f1, "https://x/2010/", tile_ids = NULL)
  expect_equal(m1$year, c(2010L, 2010L))
  expect_equal(m1$start, as.Date(c("2010-01-01", "2010-02-01")))
  f2 <- c("Combined_TPSCE_1981213.dat", "Combined_TPSCE_1981214.dat")
  m2 <- .glass_year_manifest("X_TEST", list(verified = FALSE, code = NA_character_),
                             f2, "https://x/1981/", tile_ids = NULL)
  # 1981213 = 1981 doy 213;尾部码走 (19|20)\d{5}
  expect_equal(m2$year, c(1981L, 1981L))
  expect_true(!is.na(m2$start[1]))
  expect_equal(as.integer(format(m2$start[1], "%j")), 213L)
})

test_that("年筛选:span 覆盖区/start 落区/年度单文件整年保留", {
  df <- data.frame(year = 2018L, start = as.Date(c(
    "2018-07-20", "2018-07-28", "2018-08-05", "2018-08-13")))
  fspan <- .glass_year_filter(df, as.Date("2018-08-01"), as.Date("2018-08-15"), "span")
  # 7-20 的覆盖到 7-27(不沾 8-01,剔除);7-28 覆盖到 8-04(沾住,保留)
  expect_equal(fspan$start, as.Date(c("2018-07-28", "2018-08-05", "2018-08-13")))
  fstart <- .glass_year_filter(df, as.Date("2018-08-01"), as.Date("2018-08-15"), "start")
  expect_equal(fstart$start, as.Date(c("2018-08-05", "2018-08-13")))
  # 单一 start(年度单文件):整年保留
  single <- data.frame(year = 2018L, start = as.Date("2018-01-01"))
  expect_equal(nrow(.glass_year_filter(single, as.Date("2018-08-01"),
                                       as.Date("2018-08-15"), "span")), 1L)
  # 全部无 start:原样保留
  blank <- data.frame(year = 2018L, start = as.Date(c(NA, NA)))
  expect_equal(nrow(.glass_year_filter(blank, as.Date("2018-08-01"),
                                       as.Date("2018-08-15"), "span")), 2L)
})
