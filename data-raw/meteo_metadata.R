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
networks = "DCP" # use networks = c("COOP", "DCP") for daily NOAA COOP data too

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

  } # end networks loop

  # Download and bind var info by state
  tmp_url = paste0(url_var_01, states[i],
                   url_var_02)
  hads_var_meta <- dplyr::bind_rows(hads_var_meta,
                                    read.csv(tmp_url))
} # end states loop

# Name the var of interest (air temperature)
var = "TA"

# Filter to only stations that monitor that var
hads_var_meta <- hads_var_meta %>%
  dplyr::filter(dplyr::if_any(pe1:pe25, ~ . == var))

# Trim the station metadata to only those that measure TA
# And remove known bad stations from prev work
stations_remove <- c("WRSV1", "XONC1", "DPHC1", "DKKC2", "CNLC1")
hads_meta <- hads_meta %>%
  dplyr::filter(stid %in% hads_var_meta$nwsli) %>%
  dplyr::filter(!(stid %in% stations_remove))

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

# First access the metadata from NOAA
# https://www.ncei.noaa.gov/maps/lcd/
# Grab the metadata via REST endpoint
# https://www.ncei.noaa.gov/metadata/geoportal/rest/metadata/item/gov.noaa.ncdc:C00684/html
lcd_meta <- read.csv("data-raw/lcd_station_metadata.csv")

# Format date and filter to current stations only
lcd_meta <- lcd_meta %>%
  # Not sure what the 'LOC_' cols are for?
  dplyr::select(-c(LOC_BEGIN_DATE, LOC_END_DATE)) %>%
  dplyr::mutate(short_id = stringr::str_sub(STATION_ID, 6, 10),
                # Note that the DATA_END_DATE date is based on when the metadata was accessed - 2025-05-06
                dplyr::mutate(dplyr::across(DATA_BEGIN_DATE:DATA_END_DATE, ~ as.POSIXct(. / 1000, origin = "1970-01-01", tz = "UTC"))),
                # To capture stations that may have seasonal data reporting
                ACTIVE = dplyr::case_when(as.Date(DATA_END_DATE) > as.Date("2024-01-01") ~ 1,
                                          TRUE ~ 0)) %>%
  dplyr::filter(ACTIVE == 1)

# URL for finding station codes
baseURL = "https://www.ncei.noaa.gov/data/local-climatological-data/access/"
year = 2025

# Build URL
URL = paste0(baseURL, year)

# Get all links from URL
links_full <- rvest::read_html(URL) %>%
  rvest::html_nodes("a") %>%
  rvest::html_attr('href')
links <- links_full %>%
  stringr::str_sub(7,11)

# Make data frame to store info
info <- data.frame()

# Loop through IDs to finding matching stations and URLS
for(j in 1:length(lcd_meta$short_id)){
  # Check for partial match in station ID and URLs
  link.match = stringr::str_detect(links, pattern = lcd_meta[j, "short_id"])

  # Find n matches
  matches = logical()
  matches = which(link.match == TRUE)

  # Skip or download
  print(paste("Station id =", lcd_meta[j, "short_id"]))

  if(length(matches) == 0){
    print("No match found, going to next station")
    # Extract info for station and data
    tmp.info <- data.frame(short_id = lcd_meta[j, "short_id"],
                           id = NA,
                           name = lcd_meta[j, "STATION_ID"],
                           n_matches = length(matches),
                           link = NA)
    info <- dplyr::bind_rows(info, tmp.info)
  } else if(length(matches) > 0){
    print(paste(length(matches), "match(es) found"))
    for(k in 1:length(matches)){
      # Link to met data
      met.link = paste0(URL, "/",
                        links_full[matches[k]])
      # Extract info for station and data
      tmp.info <- data.frame(short_id = lcd_meta[j, "short_id"],
                             id = substr(links_full[matches[k]], 1, 11),
                             name = lcd_meta[j, "STATION_ID"],
                             n_matches = length(matches),
                             link = met.link)
      info <- dplyr::bind_rows(info, tmp.info)
    }
  }
}

# Join the data
lcd_meta <- dplyr::left_join(lcd_meta,
                             info,
                             by = c("short_id", "STATION_ID" = "name"))

# Add timezone info
# Needed for local time to UTC conversions
lcd_meta <- lcd_meta %>%
  dplyr::mutate(timezone = lutz::tz_lookup_coords(lat = LATITUDE,
                                                  lon = LONGITUDE,
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
all_meta <-
  dplyr::bind_rows(
    hads_meta %>%
      dplyr::select(name = station_name,
                    id = stid,
                    lat, lon, elev,
                    timezone_lst) %>%
      dplyr::mutate(network = "hads"),
    lcd_meta %>%
      dplyr::select(name = STATION_ID,
                    id,
                    lat = LATITUDE,
                    lon = LONGITUDE,
                    elev = ELEVATION,
                    timezone_lst) %>%
      dplyr::mutate(network = "lcd"),
    wcc_meta %>%
      dplyr::select(name = site_name,
                    id = station.id,
                    lat, lon,
                    elev = elev_m,
                    timezone_lst,
                    network) %>%
      dplyr::mutate(id = as.character(id)),
  )

################################################################################
# Add the metadata to sysdata for package
################################################################################

usethis::use_data(hads_meta, lcd_meta, wcc_meta, all_meta,
                  internal = TRUE, overwrite = TRUE)
