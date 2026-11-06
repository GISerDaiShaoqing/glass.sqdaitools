test_that("granule grouping parses names without touching disk", {
  fake <- c(
    "https://x/GLASS01D01.V60.A2018217.h28v05.2022013.hdf",
    "https://x/GLASS01D01.V60.A2018217.h27v05.2022013.hdf",
    "/d/GLASS13D01.V10.A2019325.h28v05.2023064.hdf"
  )
  grps <- .glass_group_granules(fake)
  expect_false(is.null(grps))
  expect_equal(length(grps), 2L)
  g1 <- grps[[1]]
  expect_equal(g1$label, "A2018217")
  expect_equal(as.Date(g1$date), as.Date("2018-08-05"))
  expect_equal(length(g1$paths), 2L)
  g2 <- grps[[2]]
  expect_equal(g2$label, "A2019325")
})

test_that("grouping rejects non-GLASS names", {
  expect_error(
    .glass_group_granules(c("/tmp/whatever.tif")),
    "without the '.A<year>",
  )
})
