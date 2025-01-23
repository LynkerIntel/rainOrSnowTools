## code to prepare `product_versions` dataset goes here

# list of available GPM IMERG product versions

# used in construct_gpm_product, construct_gpm_base_url and get_imerg
product_versions = list(
  "GPM_3IMERGHHL.06" = "https://gpm1.gesdisc.eosdis.nasa.gov/opendap/hyrax/GPM_L3/GPM_3IMERGHHL.06",
  "GPM_3IMERGHHE.06" = "https://gpm1.gesdisc.eosdis.nasa.gov/opendap/hyrax/GPM_L3/GPM_3IMERGHHE.06",
  "GPM_3IMERGHHL.07" = "https://gpm1.gesdisc.eosdis.nasa.gov/opendap/hyrax/GPM_L3/GPM_3IMERGHHL.07",
  "GPM_3IMERGHH.07"  = "https://gpm1.gesdisc.eosdis.nasa.gov/opendap/hyrax/GPM_L3/GPM_3IMERGHH.07"
)

usethis::use_data(product_versions, overwrite = TRUE)
