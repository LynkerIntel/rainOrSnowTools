library(testthat)


testthat::test_that("lat/lon near main is correctly identified as Maine", {

  lat = 44.91
  lon = -66.99

  testthat::expect_equal(
    rainOrSnowTools:::get_state(lon, lat),
    "Maine"
  )

})
