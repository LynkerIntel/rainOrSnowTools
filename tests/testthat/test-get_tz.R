library(testthat)

testthat::test_that("get_tz returns Los Angeles timezone with Los Angeles lat/lon", {

  lat = 34.0549
  lon = 118.2426

  timezone = rainOrSnowTools:::get_tz(lat_obs = lat, lon_obs = lon)

  testthat::expect_equal(timezone, "Etc/GMT+-8")

}
)

testthat::test_that("get_tz throws an error if you give boolean values for lat/lon", {

  lat = TRUE
  lon = FALSE

  testthat::expect_error(
    rainOrSnowTools:::get_tz(lat_obs = lat, lon_obs = lon)
  )

}
)

testthat::test_that("get_tz throws an error if you give invalid lat/lon", {

  lat = 100000000000000
  lon = 100000000000000

  testthat::expect_error(
    rainOrSnowTools:::get_tz(lat_obs = lat, lon_obs = lon)
  )

})
