library(testthat)


testthat::test_that("lat/lon correctly identified as Maine", {

  lat = 44.91
  lon = -66.99

  testthat::expect_equal(
    rainOrSnowTools:::get_state(lon, lat),
    "Maine"
  )

})

testthat::test_that("lat/lon correctly identified as Massachusetts", {

  lat = 41.67963
  lon = -70.65786

  testthat::expect_equal(
    rainOrSnowTools:::get_state(lon, lat),
    "Massachusetts"
  )

})


testthat::test_that("lat/lon correctly identified as Nebraska", {

  lat = 40.065841
  lon = -102.050707

  testthat::expect_equal(
    rainOrSnowTools:::get_state(lon, lat),
    "Nebraska"
  )

})

testthat::test_that("lat/lon correctly identified as Florida", {

  lat = 29.012448
  lon = -80.836864

  testthat::expect_equal(
    rainOrSnowTools:::get_state(lon, lat),
    "Florida"
  )

})

# TODO: Eventually add territories into the shapefile
testthat::test_that("lat/lon correctly identified as NA because it's in Puerto Rico", {

  lat = 18.39
  lon = -66.58

  testthat::expect_equal(
    rainOrSnowTools:::get_state(lon, lat),
    as.character(NA)
  )

})

testthat::test_that("lat/lon correctly identified as NA because it's somewhere in France", {

  lat = 44.097560
  lon = 5.269866

  testthat::expect_equal(
    rainOrSnowTools:::get_state(lon, lat),
    as.character(NA)
  )

})
