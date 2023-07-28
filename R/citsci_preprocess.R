# Functions for processing raw Mountain Rain or Snow citizen science observations

# # Load packages
# library(tidyverse)
# library(lubridate)
# library(cowplot); theme_set(theme_cowplot())
# library(sp)
# library(rgdal)
# library(raster)
# library(lutz) # time zone calculations

`%>%` <- dplyr::`%>%` # add dplyr pipe

#' Get the time zone for an observation with a latitude and longitude
#'
#' @param lon_obs longitude of observation in decimal degrees (°)
#' @param lat_obs latitude of observation in decimal degrees (°)
#'
#' @return the local standard time zone in the format "Etc/GMT+X"
#' where X is the offset in hours from GMT
#'
#' @examples
#' lon = -120
#' lat = 40
#' get_tz(lon, lat)
get_tz <- function(lon_obs, lat_obs){
  # Make the timezone table
  tz_table <- make_tz_table()

  # Get the standard timezone of the obs
  tmp_tz <- data.frame(
    tz_name = lutz::tz_lookup_coords(lat = lat_obs,
                                   lon = lon_obs,
                                   method = "accurate"))

  # Join the tz_table
  tmp_tz = dplyr::left_join(tmp_tz, tz_table,
                            by = "tz_name")

  # Output the timezone
  tmp_tz$timezone_lst
}

#' Build a table of timezones and offsets when called from get_tz
#'
#' @return A table of PST, MST, CST, and EST timezones
#'
make_tz_table <- function(){

  # TODO: only support 4 time zones currently
  # Add support for more

  # Build out table for Pacific, Mountain, Central, and Eastern Standard Times
  lutz::tz_list() %>%
    dplyr::filter(zone %in% c("PST", "MST", "CST", "EST")) %>%
    dplyr::mutate(timezone_lst = paste0("Etc/GMT+", (utc_offset_h * (-1))))
}

#' Get elevation based on lat/lon
#'
#' @return Elevation based on location
#'
get_elev <- function(lon_obs, lat_obs){
  locs = cbind(lon_obs, lat_obs)
  r = terra::rast("/vsicurl/https://prd-tnm.s3.amazonaws.com/StagedProducts/Elevation/13/TIFF/USGS_Seamless_DEM_13.vrt")
  terra::extract(r, locs) %>% as.numeric()
}

#' Geolocate location to assign state and ecoregion association
#'
#' @return State and ecoregion
#'
get_eco_level3 <- function(lon_obs, lat_obs){

  locs = sf::st_as_sf(data.frame(lon_obs, lat_obs),
                          coords = c("lon_obs", "lat_obs"), crs = 4326)

 suppressMessages(suppressWarnings({

   sf::sf_use_s2(FALSE)

   sf::st_intersection(locs, ecoregions_states) %>%
     dplyr::select("Ecoregion" = US_L3NAME) %>%
     sf::st_drop_geometry() %>%
     as.character()

 }))

}

get_eco_level4 <- function(lon_obs, lat_obs){

  locs = sf::st_as_sf(data.frame(lon_obs, lat_obs),
                      coords = c("lon_obs", "lat_obs"), crs = 4326)

  suppressMessages(suppressWarnings({

    sf::sf_use_s2(FALSE)

    sf::st_intersection(locs, ecoregions_states) %>%
      dplyr::select("Ecoregion" = US_L4NAME) %>%
      sf::st_drop_geometry() %>%
      as.character()

  }))

}

get_state <- function(lon_obs, lat_obs){

  locs = sf::st_as_sf(data.frame(lon_obs, lat_obs),
                      coords = c("lon_obs", "lat_obs"), crs = 4326)

  suppressMessages(suppressWarnings({

    sf::sf_use_s2(FALSE)

    sf::st_intersection(locs, ecoregions_states) %>%
      dplyr::select("State" = STATE_NAME) %>%
      sf::st_drop_geometry() %>%
      as.character()


  }))

}

# # Import the citizen science data
# obs <- read.csv(raw.file,
#                 stringsAsFactors = F) %>%
#   rename("phase" = "precipitation") %>%
#   mutate(timezone = tz_lookup_coords(lat = latitude,
#                                      lon = longitude,
#                                      method = "accurate")) %>%
#   split(.$timezone)
#
# # Calculate time info
# # Note this is more complex than just calculating a new column
# # Why? R no likey multiple time zones in one column
# # So we split out time zones into different list elements
# # Then compute local time info, convert to UTC and join everything back together
# obs <- lapply(obs, function(x){
#   data.frame(x) %>%
#     mutate(#datetime = with_tz(time = x$createdAt,
#       #                  tzone = x[[1, "timezone"]]),
#       datetime = as.POSIXct(x = x$createdAt,
#                             tz = x[[1, "timezone"]]),
#       date = as.Date(datetime, tz = x[[1, "timezone"]]),
#       year = year(date),
#       month = month(date),
#       day = day(date),
#       hour = hour(datetime),
#       minute = minute(datetime),
#       second = second(datetime),
#       day_of_week = weekdays(datetime),
#       doy = yday(datetime),
#       dowy = ifelse(year %% 4 == 0,
#                     ifelse(month >= 10,
#                            doy - 274,
#                            doy + 92),
#                     ifelse(month >= 10,
#                            doy - 273,
#                            doy + 92)),
#       utc_datetime = with_tz(time = datetime,
#                              tzone = "UTC"),
#       datetime = NULL)
# })
#
# # Bind all the data back together
# obs <- plyr::ldply(obs, bind_rows)
#
# # Add id
# obs$id <- 1:length(obs$phase)
#
# # Import ecoregion data
# eco <- readOGR(dsn = "data/geospatial/", layer = "us_eco_l4_no_st_4326") %>%
#   spTransform(., CRS("+init=epsg:4326"))
#
# # Import state data
# states <- readOGR(dsn = "data/geospatial/", layer = "USA_adm1_WGS84") %>%
#   spTransform(., CRS("+init=epsg:4326"))
#
# ################################################################################
# #########################  Data Joins and Extraction  ##########################
# ################################################################################
#
# # Convert the data to spatial object
# # Extract the relevant info for spatial conversion
# coords <- dplyr::select(obs, longitude, latitude)
# ids <- dplyr::select(obs, id)
# crs_obs <- CRS("+init=epsg:4326")
#
# # Convert obs to a SpatialPointsDataFrame
# obs_sp <- SpatialPointsDataFrame(coords = coords,
#                                  data = ids,
#                                  proj4string = crs_obs)
#
# # Use sp::over to perform spatial join of obs and eco & states data
# obs <- bind_cols(obs,
#                  sp::over(obs_sp, eco),
#                  sp::over(obs_sp, states))
#
# ################################################################################
# #########################  Reformat and Export Data  ###########################
# ################################################################################
#
# # Filter out data outside the US and without a valid phase
# obs <- obs %>%
#   filter(!is.na(US_L3NAME) & phase != " - ")
# obs_sp <- obs_sp[obs_sp$id %in% obs$id, ]
#
# # Select and rename relevant data
# obs <- obs %>%
#   dplyr::select(., id,
#                 datetime_local_obs = createdAt,
#                 datetime_local_sub = updatedAt,
#                 observer:utc_datetime,
#                 eco_l4 = US_L4NAME,
#                 eco_l3 = US_L3NAME,
#                 eco_l2 = NA_L2NAME,
#                 state = NAME_1)
#
# # Export the preprocessed dataset
# saveRDS(object = obs,
#         file = export.file)
#
# # Export the preprocessed shapefile
# writeOGR(obs_sp,
#          dsn = export.shape.dsn,
#          layer = export.shape.layer,
#          driver = "ESRI Shapefile")
