library(testthat)

testthat::test_that("get_available_networks with LCD", {

  test_that("returns base networks always", {
    dt <- as.POSIXct("2025-08-26 23:59:59", tz = "UTC")
    result <- get_available_networks(dt)

    expect_true("LCD" %in% result)
  })

})

test_that("excludes LCD after cutoff when include_deprecated = FALSE", {
  dt <- as.POSIXct("2025-08-27 00:00:01", tz = "UTC")
  result <- get_available_networks(dt)

  expect_false("LCD" %in% result)
})

test_that("includes LCD after cutoff when include_deprecated = TRUE", {
  dt <- as.POSIXct("2025-08-27 00:00:01", tz = "UTC")
  result <- get_available_networks(dt, include_deprecated = TRUE)

  expect_true("LCD" %in% result)
})

test_that("returns a character vector", {
  dt <- as.POSIXct("2024-01-01", tz = "UTC")
  result <- get_available_networks(dt)

  expect_type(result, "character")
})
