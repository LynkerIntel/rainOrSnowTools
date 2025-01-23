library(testthat)

testthat::test_that("testing invalid product versions throws an error", {

  bad_product_versions = list(FALSE, "i love cats", "tests are good", list())

  for (bad_product_version in bad_product_versions) {
    testthat::expect_error(
      construct_gpm_base_url("2024-01-25T01:45:59.000Z",  bad_product_version)
    )
  }

})
