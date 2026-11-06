test_that("glass_registry filters correctly", {
  all <- glass_registry()
  expect_gt(nrow(all), 50L)
  expect_s3_class(all, "tbl_df")

  lai <- glass_registry(product = "LAI")
  expect_true(all(lai$product == "LAI"))

  ver <- glass_registry(verified_only = TRUE)
  expect_true(all(ver$verified))
  expect_true("LAI_MODIS_250M" %in% ver$variant_id)
})

test_that("glass_product_info errors and resolves", {
  expect_error(glass_product_info(), "must be provided")
  row <- glass_product_info(variant_id = "LAI_MODIS_250M")
  expect_equal(nrow(row), 1L)
  expect_true(row$verified)
  expect_equal(row$fill_value, 255)
  expect_equal(row$scale_factor, 0.1)
  expect_error(glass_product_info(variant_id = "NOT_A_VARIANT"), "No registry rows match")
  multi <- glass_product_info(product = "LAI")
  expect_gt(nrow(multi), 1L)
})

test_that(".glass_tile_ids normalizes input", {
  expect_equal(.glass_tile_ids("h28v05"), "h28v05")
  expect_equal(.glass_tile_ids(c("h28v05", "h27v05")), c("h28v05", "h27v05"))
  df <- data.frame(h = c(28L, 27L), v = c(5L, 5L))
  expect_equal(.glass_tile_ids(df), c("h28v05", "h27v05"))
  expect_error(.glass_tile_ids(123), "must be a character vector")
})
