library(testthat)

testthat::test_that("download_meteo_madis returns correct structure", {

  lon_obs <- -105
  lat_obs <- 40
  deg_filter <- 1
  datetime_utc_obs <- as.POSIXct("2025-10-01 15:00:00", tz = "UTC")

  res <- rainOrSnowTools::download_meteo_madis(lon_obs, lat_obs, deg_filter, datetime_utc_obs)

  # List check
  testthat::expect_true(is.list(res))

  # Named list
  testthat::expect_named(res, c("observations", "stations"))

  # Data frames
  testthat::expect_s3_class(res$observations, "data.frame")
  testthat::expect_s3_class(res$stations, "data.frame")

  # Required columns
  required_obs_cols <- c("STAID", "LAT", "LON", "ELEV", "PVDR", "SUBPVDR", "T", "TD", "TWB", "RH")
  testthat::expect_true(all(required_obs_cols %in% names(res$observations)))

  required_station_cols <- c("STAID", "LAT", "LON", "ELEV", "PVDR", "SUBPVDR")
  testthat::expect_true(all(required_station_cols %in% names(res$stations)))
})

testthat::test_that("download_meteo_madis with outside CONUS lat/lon", {

  # Somehwere in France:
  lon_obs <- 0.847763
  lat_obs <- 47.540714
  deg_filter <- 1
  datetime_utc_obs <- as.POSIXct("2024-09-01 15:00:00", tz = "UTC")

  res <- rainOrSnowTools::download_meteo_madis(lon_obs, lat_obs, deg_filter, datetime_utc_obs)
  # There is indeed data!

  # List check
  testthat::expect_true(is.list(res))

  # Named list
  testthat::expect_named(res, c("observations", "stations"))

  # Data frames
  testthat::expect_s3_class(res$observations, "data.frame")
  testthat::expect_s3_class(res$stations, "data.frame")

  # Required columns
  required_obs_cols <- c("STAID", "LAT", "LON", "ELEV", "PVDR", "SUBPVDR", "T", "TD", "TWB", "RH")
  testthat::expect_true(all(required_obs_cols %in% names(res$observations)))

  required_station_cols <- c("STAID", "LAT", "LON", "ELEV", "PVDR", "SUBPVDR")
  testthat::expect_true(all(required_station_cols %in% names(res$stations)))
})
