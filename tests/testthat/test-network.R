# 网络集成测试:默认跳过;GLASS_SMOKE=1 时执行(R CMD check 时不联网)
test_that("live listing returns exactly one LAI granule for h28v05", {
  skip_if_not(identical(Sys.getenv("GLASS_SMOKE", "0"), "1"),
              "set GLASS_SMOKE=1 to enable network tests")
  m <- glass_list_files("LAI_MODIS_250M", year = 2018, doy = 217,
                        tiles = "h28v05")
  expect_equal(nrow(m), 1L)
  expect_equal(m$tile, "h28v05")
  expect_true(startsWith(m$filename, "GLASS01D01"))
})
