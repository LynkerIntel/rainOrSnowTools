## code to prepare the metadata for the meteorological stations goes here

# Get the pipe
`%>%` <- dplyr::`%>%` # add dplyr pipe

# Make a timezone table
# LCD and WCC are always reported in local standard time, no need to get daylight conversions
tz_table <- lutz::tz_list() %>%
  dplyr::filter(zone %in% c("PST", "MST", "CST", "EST", "AKST")) %>%
  dplyr::mutate(timezone_lst = paste0("Etc/GMT+", (utc_offset_h * (-1))))

################################################################################
# Script for processing HADS DCP metadata
################################################################################

# Get all locations (50 states + DC)
states = c(state.abb, "DC")
networks = c("DCP", "COOP") # use networks = c("COOP", "DCP") for daily NOAA COOP data too

# URL strings for station info by state
url_01 = "https://mesonet.agron.iastate.edu/sites/networks.php?network="
url_02 = "_"
url_03 = "&format=csv&nohtml=on"

# URL strings for var info by station by state
url_var_01 = "https://hads.ncep.noaa.gov/csv/"
url_var_02 = ".csv"

# Empty dataframes
hads_meta <- data.frame()
hads_var_meta <- data.frame()

# Loop through states
for(i in 1:length(states)){
  # Loop through networks
  for(j in 1:length(networks)){
    tmp_url = paste0(url_01, states[i],
                     url_02, networks[j],
                     url_03)
    hads_meta <- dplyr::bind_rows(hads_meta,
                                  read.csv(tmp_url))

  } # End networks loop

  # Download and bind var info by state
  tmp_url = paste0(url_var_01, states[i],
                   url_var_02)
  hads_var_meta <- dplyr::bind_rows(hads_var_meta,
                                    read.csv(tmp_url))
} # end states loop

# Name the vars of interest
var <- c(
  "TA",  # Air temperature (dry bulb)
  "TD",  # Dew point temperature
  "US",  # Wind speed
  "UG",  # Wind gust
  "UD",  # Wind direction (associated with gusts/wind)
  "XR",  # Relative humidity
  "PP",  # Precipitation increment
  "PC",  # Precipitation accumulated
  "PR"   # Precipitation rate
)

# Filter to only stations that monitor that var
hads_var_meta <- hads_var_meta %>%
  dplyr::filter(dplyr::if_any(pe1:pe25, ~ . == var))

# Trim the station metadata to only those that measure TA
# And remove known bad stations from prev work
stations_remove <- c("WRSV1", "XONC1", "DPHC1", "DKKC2", "CNLC1")
hads_meta <- hads_meta %>%
  dplyr::filter(stid %in% hads_var_meta$nwsli) %>%
  dplyr::filter(!(stid %in% stations_remove)) %>%
  dplyr::filter(endts == "")

# Add timezone info
# Needed for local time to UTC conversions
hads_meta <- hads_meta %>%
  dplyr::mutate(timezone = lutz::tz_lookup_coords(lat = lat,
                                                  lon = lon,
                                                  method = "accurate"))

# Join timezone info
hads_meta <- dplyr::left_join(hads_meta,
                             dplyr::select(tz_table,
                                           timezone = tz_name,
                                           timezone_lst),
                             by = "timezone")

################################################################################
# Script for processing LCD metadata
################################################################################

################### OLD METHOD ####################
# First access the metadata from NOAA
# https://www.ncei.noaa.gov/maps/lcd/
# Grab the metadata via REST endpoint
# https://www.ncei.noaa.gov/metadata/geoportal/rest/metadata/item/gov.noaa.ncdc:C00684/html
###################################################

# NOAA provides a station list
lcd_lines <- readLines("https://www.ncei.noaa.gov/oa/local-climatological-data/v2/doc/lcdv2-station-list.txt")

# Format the data
lcd_lines <- stringr::str_squish(lcd_lines)
lcd_meta <- as.data.frame(stringr::str_split_fixed(lcd_lines, " ", 5))

colnames(lcd_meta) <- c("stid", "lat", "lon", "elev_m", "station_name")

# Add timezone info
# Needed for local time to UTC conversions
lcd_meta <- lcd_meta %>%
  dplyr::mutate(across(c(lat, lon, elev_m), as.numeric)) %>%
  dplyr::mutate(timezone = lutz::tz_lookup_coords(lat = lat,
                                                  lon = lon,
                                                  method = "accurate"))

# Join timezone info
lcd_meta <- dplyr::left_join(lcd_meta,
                             dplyr::select(tz_table,
                                           timezone = tz_name,
                                           timezone_lst),
                             by = "timezone")

################################################################################
# Script for processing WCC metadata
################################################################################

# You can access current station info at
# https://wcc.sc.egov.usda.gov/nwcc/inventory
# Grabbed Air T metadata because dbl checked that these stations also report:
# Dew Point Temperature,Relative Humidity,Precipitation Accumulation
wcc_meta <- read.csv("data-raw/nwcc_inventory.csv")

# Add a timezone column
wcc_meta <- wcc_meta %>%
  dplyr::mutate(timezone_lst = paste0("Etc/GMT+", gmt_offset),
                # elevation provided are in feet
                elev_m = elev*0.3048)

################################################################################
# Collate the metadata into a single dataframe
################################################################################

# This is not necessary anymore.. using 'metadata_gather' instead
# all_meta <-
#   dplyr::bind_rows(
#     hads_meta %>%
#       dplyr::select(name = station_name,
#                     id = stid,
#                     lat, lon, elev,
#                     timezone_lst) %>%
#       dplyr::mutate(network = "hads"),
#     lcd_meta %>%
#       dplyr::select(name = STATION_ID,
#                     id,
#                     lat = LATITUDE,
#                     lon = LONGITUDE,
#                     elev = ELEVATION,
#                     timezone_lst) %>%
#       dplyr::mutate(network = "lcd"),
#     wcc_meta %>%
#       dplyr::select(name = site_name,
#                     id = station.id,
#                     lat, lon,
#                     elev = elev_m,
#                     timezone_lst,
#                     network) %>%
#       dplyr::mutate(id = as.character(id))
#   )

################################################################################
# Add the metadata to sysdata for package
################################################################################

usethis::use_data(hads_meta, lcd_meta, wcc_meta,
                  # all_meta,
                  internal = TRUE, overwrite = TRUE)
