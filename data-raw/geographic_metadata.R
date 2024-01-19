# Code to prepare the metadata for the geographical data goes here

# Get the pipe
`%>%` <- dplyr::`%>%` # add dplyr pipe

################################################################################
# Script for ecoregion and state data
# This only supports CONUS
################################################################################

get_ecoregion = function(level = level){

  temp = tempfile()
  eco = tempfile()

  URL_conus = glue::glue("https://gaftp.epa.gov/EPADataCommons/ORD/Ecoregions/us/us_eco_l{level}_state_boundaries.zip")

  # Increase timeout
  options(timeout = 100)

  download.file(URL_conus, temp)

  # Unzip the contents of the temp and save unzipped contents in 'eco'
  unzip(zipfile = temp, exdir = eco)

  # Read the shapefile
  sf::read_sf(eco) %>%
    sf::st_make_valid() %>%
    rmapshaper::ms_simplify(keep_shapes = TRUE) %>%
    sf::st_transform(crs = 4326)

}

################################################################################
# Alaska support
# Ecoregion levels I-III
################################################################################

temp_ak = tempfile()
eco_ak = tempfile()

URL_ak = "https://gaftp.epa.gov/EPADataCommons/ORD/Ecoregions/ak/ak_eco_l3.zip"
download.file(URL_ak, temp_ak)

unzip(zipfile = temp_ak, exdir = eco_ak)

ak_ecoregion = sf::read_sf(eco_ak) %>%
  sf::st_make_valid() %>%
  rmapshaper::ms_simplify(keep_shapes = TRUE) %>%
  sf::st_transform(crs = 4326)

################################################################################
# Bind data
# Get ecoregion level IV for CONUS and bind data for ecoregion level III AK
# Note: Alaska ecoregion level IV does not exist, so it will return NA
################################################################################

conus_ecoregion = get_ecoregion(4)
ecoregions_states = dplyr::bind_rows(conus_ecoregion, ak_ecoregion)

# ################################################################################
# Add the metadata to sysdata for package
# ################################################################################

sysdata <- load("R/sysdata.rda")
save(list = c(sysdata, "ecoregions_states"), file = "R/sysdata.rda")
