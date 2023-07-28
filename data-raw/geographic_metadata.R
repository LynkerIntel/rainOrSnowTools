# Get the pipe
`%>%` <- dplyr::`%>%` # add dplyr pipe

################################################################################
# Script for ecoregion and state data
################################################################################

get_ecoregion = function(level = level){

  temp = tempfile()
  eco = tempfile()

  URL = glue::glue("https://gaftp.epa.gov/EPADataCommons/ORD/Ecoregions/us/us_eco_l{level}_state_boundaries.zip")

  download.file(URL, temp)

  # Unzip the contents of the temp and save unzipped contents in 'eco'
  unzip(zipfile = temp, exdir = eco)

  # Read the shapefile
  sf::read_sf(eco) %>%
    sf::st_make_valid() %>%
    rmapshaper::ms_simplify(keep_shapes = TRUE) %>%
    sf::st_transform(crs = 4326)

}

# Test if this works
# ecoregions_3_states = get_ecoregion(3)

# Just use this because also provides ecoregion information for all levels
ecoregions_states = get_ecoregion(4)

################################################################################
# Add the metadata to sysdata for package
################################################################################

usethis::use_data(ecoregions_states,
                  internal = TRUE, overwrite = TRUE)
