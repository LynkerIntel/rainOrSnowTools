library(testthat)

testthat::test_that(
  "testing get_valid_product_version_for_date() for varying dates, should default to v7", {

    version_name = 'GPM_3IMERGHHL.06'

    dates_list = list(
      as.POSIXct("2022-06-01T01:45:59.000Z", format = "%Y-%m-%dT%H:%M:%OS",  tz = "UTC"),
      as.POSIXct("2023-06-10T01:45:59.000Z", format = "%Y-%m-%dT%H:%M:%OS",  tz = "UTC"),
      as.POSIXct("2024-07-10T01:45:59.000Z", format = "%Y-%m-%dT%H:%M:%OS",  tz = "UTC"),
      as.POSIXct("2025-08-10T01:45:59.000Z", format = "%Y-%m-%dT%H:%M:%OS",  tz = "UTC"),
      as.POSIXct("2025-10-10T01:45:59.000Z", format = "%Y-%m-%dT%H:%M:%OS",  tz = "UTC")
    )

    for (date_utc in dates_list) {
      testthat::expect_equal(
        rainOrSnowTools:::get_valid_product_version_for_date(version_name, date_utc),
        "GPM_3IMERGHHL.07"
      )
      testthat::expect_message(
        rainOrSnowTools:::get_valid_product_version_for_date(version_name, date_utc),
        "IMERGv6 is no longer supported 2024-06-01, defaulting to using IMERGv7"
      )
    }

  }
)
