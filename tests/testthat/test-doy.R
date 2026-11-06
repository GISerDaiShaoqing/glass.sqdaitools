test_that("8-day folders match the legacy script enumeration", {
  d <- glass_doys("LAI_MODIS_250M", "2018-08-01", "2018-12-31", mode = "start")
  expect_identical(d$folder, sprintf("%03d", seq(217, 361, 8)))
  expect_true(all(d$year == 2018))
})

test_that("span mode keeps partially overlapping composites", {
  d <- glass_doys("LAI_MODIS_250M", "2018-08-01", "2018-08-31", mode = "span")
  expect_true("209" %in% d$folder)
  expect_true("241" %in% d$folder)
  expect_false("249" %in% d$folder)
})

test_that("cross-year range returns folders from both years", {
  d <- glass_doys("LAI_MODIS_250M", "2018-12-20", "2019-01-20", mode = "span")
  expect_true(2018 %in% d$year)
  expect_true(2019 %in% d$year)
  d2 <- glass_doys("LAI_MODIS_250M", "2019-01-01", "2019-01-31", mode = "start")
  expect_identical(d2$folder, c("001", "009", "017", "025"))
})

test_that("errors are controlled", {
  expect_error(glass_doys("LAI_MODIS_250M", "2018-01-02", "2018-01-01"), "later")
  # cadence 未知的变体
  expect_error(glass_doys("LAI_MODIS_0_05D", "2018-01-01", "2018-02-01"), "cadence")
})
