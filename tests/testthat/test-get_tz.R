library(testthat)

# 3 A's of unit testing:
# Arrange (setting the inputs for function)
# Act (calling the function with the inputs)
# Assert (Checking the results are as expected)

testthat::test_that("get_tz returns Los Angeles timezone with Los Angeles lat/lon", {
  # Arrange
  lat = 34.0549
  lon = 118.2426

  # Act
  timezone = rainOrSnowTools:::get_tz(lat_obs = lat, lon_obs = lon)

  # Assert
  testthat::expect_equal(timezone, "Etc/GMT+-8")

}
)

testthat::test_that("get_tz throws an error if you give boolean values for lat/lon", {
  # Arrange
  lat = TRUE
  lon = FALSE

  # Act and Assert
  testthat::expect_error(
    rainOrSnowTools:::get_tz(lat_obs = lat, lon_obs = lon)
  )

}
)

testthat::test_that("get_tz throws an error if you give invalid lat/lon", {
  # Arrange
  lat = 100000000000000
  lon = 100000000000000

  # Act and Assert
  testthat::expect_error(
    rainOrSnowTools:::get_tz(lat_obs = lat, lon_obs = lon)
  )

})
