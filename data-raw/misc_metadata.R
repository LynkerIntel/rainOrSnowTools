# Get the pipe
`%>%` <- dplyr::`%>%` # add dplyr pipe

################################################################################
# Script for ecoregion and state data
################################################################################

# Read in ecoregion and state data
# Create temp files
temp = tempfile()
eco = tempfile()

URL = "https://gaftp.epa.gov/EPADataCommons/ORD/Ecoregions/us/us_eco_l3_state_boundaries.zip"
download.file(URL, temp)

# Unzip the contents of the temp and save unzipped contents in 'eco'
unzip(zipfile = temp, exdir = eco)

# Read the shapefile
ecoregions <- sf::read_sf(eco) %>%
  sf::st_transform(ecoregions, crs = 4326) %>%
  sf::st_as_sf()

################################################################################
# Add the metadata to sysdata for package
################################################################################

usethis::use_data(ecoregions,
                  internal = TRUE, overwrite = TRUE)
