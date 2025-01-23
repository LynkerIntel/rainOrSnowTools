library(testthat)

testthat::test_that("testing get_valid_product_version_for_date() with GPM_3IMERGHHL.06 for dates before 2024-06-01", {
  version_name = 'GPM_3IMERGHHL.06'
  # version_url = "https://gpm1.gesdisc.eosdis.nasa.gov/opendap/hyrax/GPM_L3/GPM_3IMERGHHL.06"

  dates_list = list(
    as.POSIXct("2024-01-01T01:45:59.000Z", format = "%Y-%m-%dT%H:%M:%OS",  tz = "UTC"),
    as.POSIXct("2024-02-01T01:45:59.000Z", format = "%Y-%m-%dT%H:%M:%OS",  tz = "UTC"),
    as.POSIXct("2024-03-01T01:45:59.000Z", format = "%Y-%m-%dT%H:%M:%OS",  tz = "UTC"),
    as.POSIXct("2024-04-01T01:45:59.000Z", format = "%Y-%m-%dT%H:%M:%OS",  tz = "UTC")
  )

  for (date_utc in dates_list) {
    testthat::expect_equal(
      rainOrSnowTools:::get_valid_product_version_for_date(version_name, date_utc), "GPM_3IMERGHHL.06"
    )
  }

})

testthat::test_that("testing get_valid_product_version_for_date() with GPM_3IMERGHHL.06
        for dates AFTER 2024-06-01 will give GPM_3IMERGHHL.07 version AND a message", {

          version_name = 'GPM_3IMERGHHL.06'

          dates_list = list(
            as.POSIXct("2024-06-02T01:45:59.000Z", format = "%Y-%m-%dT%H:%M:%OS",  tz = "UTC"),
            as.POSIXct("2024-07-02T01:45:59.000Z", format = "%Y-%m-%dT%H:%M:%OS",  tz = "UTC"),
            as.POSIXct("2024-08-02T01:45:59.000Z", format = "%Y-%m-%dT%H:%M:%OS",  tz = "UTC"),
            as.POSIXct("2024-09-02T01:45:59.000Z", format = "%Y-%m-%dT%H:%M:%OS",  tz = "UTC")
          )

          for (date_utc in dates_list) {
            testthat::expect_equal(
              rainOrSnowTools:::get_valid_product_version_for_date(version_name, date_utc),
              "GPM_3IMERGHHL.07"
            )
            testthat::expect_message(
              rainOrSnowTools:::get_valid_product_version_for_date(version_name, date_utc),
              "rainOrSnowTools does not support IMERGv6 after 2024-06-01, defaulting to using IMERGv7"
            )
          }

        })


testthat::test_that("testing get_valid_product_version_for_date() with GPM_3IMERGHHL.07 for dates AFTER 2024-06-01", {
  version_name = 'GPM_3IMERGHHL.07'
  # version_url = "https://gpm1.gesdisc.eosdis.nasa.gov/opendap/hyrax/GPM_L3/GPM_3IMERGHHL.06"

  dates_list = list(
    as.POSIXct("2024-06-01T01:45:59.000Z", format = "%Y-%m-%dT%H:%M:%OS",  tz = "UTC"),
    as.POSIXct("2024-06-10T01:45:59.000Z", format = "%Y-%m-%dT%H:%M:%OS",  tz = "UTC"),
    as.POSIXct("2024-07-10T01:45:59.000Z", format = "%Y-%m-%dT%H:%M:%OS",  tz = "UTC"),
    as.POSIXct("2024-08-10T01:45:59.000Z", format = "%Y-%m-%dT%H:%M:%OS",  tz = "UTC"),
    as.POSIXct("2024-09-10T01:45:59.000Z", format = "%Y-%m-%dT%H:%M:%OS",  tz = "UTC")
  )

  for (date_utc in dates_list) {
    testthat::expect_equal(
      rainOrSnowTools:::get_valid_product_version_for_date(version_name, date_utc), "GPM_3IMERGHHL.07"
    )
  }

})

testthat::test_that("testing get_valid_product_version_for_date() with GPM_3IMERGHHL.07
        for dates BEFORE 2024-06-01 will give GPM_3IMERGHHL.07 version AND a message", {

          version_name = 'GPM_3IMERGHHL.07'

          dates_list = list(
            as.POSIXct("2024-05-30T01:45:59.000Z", format = "%Y-%m-%dT%H:%M:%OS",  tz = "UTC"),
            as.POSIXct("2024-05-01T01:45:59.000Z", format = "%Y-%m-%dT%H:%M:%OS",  tz = "UTC"),
            as.POSIXct("2024-04-01T01:45:59.000Z", format = "%Y-%m-%dT%H:%M:%OS",  tz = "UTC"),
            as.POSIXct("2024-03-01T01:45:59.000Z", format = "%Y-%m-%dT%H:%M:%OS",  tz = "UTC")
          )

          for (date_utc in dates_list) {
            testthat::expect_equal(
              rainOrSnowTools:::get_valid_product_version_for_date(version_name, date_utc),
              "GPM_3IMERGHHL.06"
            )

            testthat::expect_message(
              rainOrSnowTools:::get_valid_product_version_for_date(version_name, date_utc),
              "rainOrSnowTools does not support IMERGv7 before 2024-06-01, defaulting to using IMERGv6"
            )
          }

        })
