# Functions for processing raw Mountain Rain or Snow citizen science observations

# Declare global variables to pass R-CMD-check
utils::globalVariables(
  c("US_L3NAME", "US_L4NAME", "dateTime", "minTime", "rounded_time", "nasa_time", "origin_time",
    "STATE_NAME", "zone", "utc_offset_h")
)

# # Load packages
# library(tidyverse)
# library(lubridate)
# library(cowplot); theme_set(theme_cowplot())
# library(sp)
# library(rgdal)
# library(raster)
# library(lutz) # time zone calculations

#' Get the time zone for an observation with a latitude and longitude
#'
#' @param lon_obs longitude of observation in decimal degrees (°)
#' @param lat_obs latitude of observation in decimal degrees (°)
#'
#' @return the local standard time zone in the format "Etc/GMT+X"
#' where X is the offset in hours from GMT
#' @importFrom lutz tz_lookup_coords
#' @importFrom dplyr left_join `%>%`
#'
#' @examples
#' \dontrun{
#' lon = -120
#' lat = 40
#' get_tz(lon, lat)
#' }
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
  return(tmp_tz$timezone_lst)
  # tmp_tz$timezone_lst
}

#' Build a table of timezones and offsets when called from get_tz
#'
#' @return A table of PST, MST, CST, and EST timezones
#' @importFrom lutz tz_list
#' @importFrom dplyr filter mutate `%>%`
#' @export
make_tz_table <- function(){

  # TODO: only support 4 time zones currently
  # Add support for more

  # Build out table for Pacific, Mountain, Central, and Eastern Standard Times
  lutz::tz_list() %>%
    dplyr::filter(zone %in% c("PST", "MST", "CST", "EST")) %>%
    dplyr::mutate(timezone_lst = paste0("Etc/GMT+", (utc_offset_h * (-1))))
}

#' Get elevation based on lat/lon
#' @param lon_obs numeric, Longitude in decimal degrees. Default is NULL.
#' @param lat_obs numeric, Latitude in decimal degrees. Default is NULL.
#' @return Elevation based on location
#' @importFrom lutz tz_list
#' @importFrom terra rast extract
#' @export
get_elev <- function(lon_obs, lat_obs){
  locs = cbind(lon_obs, lat_obs)
  r = terra::rast("/vsicurl/https://prd-tnm.s3.amazonaws.com/StagedProducts/Elevation/13/TIFF/USGS_Seamless_DEM_13.vrt")

  # TODO: this currently returns a vector of length 2. with the ID of the point first, and the elevation second.
  # TODO: It may make more sense to either ONLY return the elevation for the point(s) as a single vector
  # TODO: OR to just return a dataframe with 2 columns, the ID and the elevation value....
  return(
    as.numeric(
      terra::extract(r, locs)
      )
    )
}

#' Geolocate location to assign ecoregion 3 association
#'
#' @return Ecoregion level 3
#' @param lon_obs numeric, Longitude in decimal degrees. Default is NULL.
#' @param lat_obs numeric, Latitude in decimal degrees. Default is NULL.
#' @importFrom sf st_as_sf sf_use_s2 st_intersection st_drop_geometry
#' @importFrom dplyr select `%>%`
#' @examples
#' \dontrun{
#' lon = -105
#' lat = 40
#' ecoregion3 <- get_eco_level3(lon, lat)
#' }
get_eco_level3 <- function(lon_obs, lat_obs){

  # get ecoregions_states data from R/sysdata.rda
  ecoregions_states <- get0("ecoregions_states", envir = asNamespace("rainOrSnowTools"))

  # sf dataframe of locations
  locs = sf::st_as_sf(
              data.frame(lon_obs, lat_obs),
              coords = c("lon_obs", "lat_obs"),
              crs    = 4326
              )

 suppressMessages(suppressWarnings({

   sf::sf_use_s2(FALSE)

   sf::st_intersection(locs, ecoregions_states) %>%
   # sf::st_intersection(locs, rainOrSnowTools::ecoregions_states) %>%
     dplyr::select("Ecoregion" = US_L3NAME) %>%
     sf::st_drop_geometry() %>%
     as.character()

 }))

}

#' Geolocate location to assign ecoregion 4 association
#'
#' @return Ecoregion level 4
#' @param lon_obs numeric, Longitude in decimal degrees. Default is NULL.
#' @param lat_obs numeric, Latitude in decimal degrees. Default is NULL.
#' @importFrom sf st_as_sf sf_use_s2 st_intersection st_drop_geometry
#' @importFrom dplyr select `%>%`
#' @examples
#' \dontrun{
#' lon = -105
#' lat = 40
#' ecoregion4 <- get_eco_level4(lon, lat)
#' }
get_eco_level4 <- function(lon_obs, lat_obs) {

  # get ecoregions_states data from R/sysdata.rda
  ecoregions_states <- get0("ecoregions_states", envir = asNamespace("rainOrSnowTools"))

  # sf dataframe of locations
  locs = sf::st_as_sf(
              data.frame(lon_obs, lat_obs),
              coords = c("lon_obs", "lat_obs"),
              crs = 4326
              )

  suppressMessages(suppressWarnings({

    sf::sf_use_s2(FALSE)

    sf::st_intersection(locs, ecoregions_states) %>%
    # sf::st_intersection(locs, rainOrSnowTools::ecoregions_states) %>%
      dplyr::select("Ecoregion" = US_L4NAME) %>%
      sf::st_drop_geometry() %>%
      as.character()

  }))

}

#' Geolocate location to assign state association
#' @param lon_obs numeric, Longitude in decimal degrees. Default is NULL.
#' @param lat_obs numeric, Latitude in decimal degrees. Default is NULL.
#' @return State
#' @importFrom sf st_as_sf sf_use_s2 st_intersection st_drop_geometry
#' @importFrom dplyr select `%>%`
#' @examples
#' \dontrun{
#' lon = -105
#' lat = 40
#' state <- get_state(lon, lat)
#' }
get_state <- function(lon_obs, lat_obs){

  # get ecoregions_states data from R/sysdata.rda
  ecoregions_states <- get0("ecoregions_states", envir = asNamespace("rainOrSnowTools"))

  # sf dataframe of locations
  locs = sf::st_as_sf(
              data.frame(lon_obs, lat_obs),
              coords = c("lon_obs", "lat_obs"),
              crs = 4326
              )

  suppressMessages(suppressWarnings({

    sf::sf_use_s2(FALSE)

    sf::st_intersection(locs, ecoregions_states) %>%
    # sf::st_intersection(locs, rainOrSnowTools::ecoregions_states) %>%
      dplyr::select("State" = STATE_NAME) %>%
      sf::st_drop_geometry() %>%
      as.character()


  }))

}

#' Download GPM IMERG data
#'
#' @param datetime_utc Observation time in UTC format YYYY-MM-DD HH:MM:SS. Default is NULL.
#' @param lon_obs numeric, Longitude in decimal degrees. Default is NULL.
#' @param lat_obs numeric, Latitude in decimal degrees. Default is NULL.
#' @return a dataframe of GPM data for each observation
#' @importFrom sf st_as_sf st_drop_geometry
#' @importFrom dplyr mutate any_of select bind_rows select `%>%`
#' @importFrom plyr round_any
#' @importFrom pacman p_load
#' @importFrom glue glue
#' @importFrom climateR dap
#' @export
#'
#' @examples
#' \dontrun{
#' datetime_utc = as.POSIXct("2023-01-01 16:00:00", tz = "UTC")
#' lon = -105
#' lat = 40
#' gpm <- get_imerg(datetime_utc, lon_obs = lon, lat_obs = lat)
#' }
get_imerg <- function(
    datetime_utc = NULL,
    lon_obs      = NULL,
    lat_obs      = NULL
    ) {

  # check for valid inputs
  if(is.null(datetime_utc)) {
    stop("Missing 'datetime_utc' argument input, 'datetime_utc' must be in format: YYYY-MM-DD HH:MM:SS")
  }

  # check for valid lon_obs input
  if(is.null(lon_obs)) {
    stop("Missing 'lon_obs' argument input, 'lon_obs' must be a numeric LONGITUDE value in CRS 4326")
  }

  # check for valid lat_obs input
  if(is.null(lat_obs)) {
    stop("Missing 'lat_obs' argument input, 'lat_obs' must be a numeric LATITUDE value in CRS 4326")
  }

  # # Package load
  # # Is this the right way to do it?
  # pacman::p_load(hydrofabric, lubridate, plyr)

  ## ASSIGN GPM variable
  var = 'probabilityLiquidPrecipitation'

  # Observation data is converted into shapefile format
  data = sf::st_as_sf(
              data.frame(datetime_utc, lon_obs, lat_obs),
              coords = c("lon_obs", "lat_obs"),
              crs    = 4326
              )

  # URL structure
  base         = 'https://gpm1.gesdisc.eosdis.nasa.gov/opendap/hyrax/GPM_L3/GPM_3IMERGHHL.06'
  product      = '3B-HHR-L.MS.MRG.3IMERG'
  url_pattern  = '{base}/{year}/{julian}/{product}.{year}{month}{day}-S{hour}{minTime}00-E{hour}{nasa_time_minute}{nasa_time_second}.{min}.V06B.HDF5'
  url_pattern2 = '{base}/{year}/{julian}/{product}.{year}{month}{day}-S{hour}{minTime}00-E{hour}{nasa_time_minute}{nasa_time_second}.{min}.V06C.HDF5'
  url_pattern3 = '{base}/{year}/{julian}/{product}.{year}{month}{day}-S{hour}{minTime}00-E{hour}{nasa_time_minute}{nasa_time_second}.{min}.V06D.HDF5'

  # ^^^^ The above resources (".V06B.HDF5", ".V06C.HDF5", ".V06D.HDF5"), do NOT exist ^^^^
  # this URL is the one that actually has an existing resource "V06E".
  url_pattern4 = '{base}/{year}/{julian}/{product}.{year}{month}{day}-S{hour}{minTime}00-E{hour}{nasa_time_minute}{nasa_time_second}.{min}.V06E.HDF5'

  l = list()

  ## Build URLs
  data =
    data %>%
    dplyr::mutate(dateTime = as.POSIXct(datetime_utc)) %>%
    dplyr::mutate(
      julian  = format(dateTime, "%j"),
      year    = format(dateTime, "%Y"),
      month   = format(dateTime, "%m"),
      day     = format(dateTime, "%d"),
      hour    = sprintf("%02s", format(dateTime, "%H")),
      minTime = sprintf("%02s",
                          plyr::round_any(as.numeric(
                            format(dateTime, "%M")
                            ), 30,
                            f = floor)
                          ),
      origin_time      = as.POSIXct(paste0(
                                      format(dateTime, "%Y-%m-%d"),
                                      "00:00"),
                                    tz = "UTC"
                                    ),
      rounded_time     = as.POSIXct(paste0(
                                  format(dateTime, "%Y-%m-%d"), hour, ":", minTime
                                ),
                                tz = "UTC"
                                ),
      nasa_time        = rounded_time + (29 * 60) + 59,
      nasa_time_minute = format(nasa_time, "%M"),
      nasa_time_second = format(nasa_time, "%S"),
      min              = sprintf("%04s", difftime(rounded_time, origin_time,  units = 'min')),
      url              = glue::glue(url_pattern),
      url2             = glue::glue(url_pattern2),
      url3             = glue::glue(url_pattern3),
      url4             = glue::glue(url_pattern4)
    ) %>%
    # !! ADD ANYTHING YOU WANT TO KEEP HERE !!
    dplyr::select(dplyr::any_of(c('datetime_utc', 'phase', 'url', 'url2', 'url3', 'url4')))

  message("Downloading GPM data...")

  message(paste0("data$url4: ", data$url4[1]))
  message(paste0("data$url: ", data$url[1]))
  message(paste0("data$url2: ", data$url2[1]))
  message(paste0("data$url3: ", data$url3[1]))
  
  ## Get Data
  # suppressMessages(
  for (x in 1:nrow(data)) {
    l[[x]] = tryCatch({
      climateR::dap(
          URL = data$url4[x],
          varname = var,
          AOI = data[x, ],
          verbose = FALSE
      )
    }, error = function(e) {
      climateR::dap(
        URL = data$url[x],
        varname = var,
        AOI = data[x, ],
        verbose = FALSE
      )
    }, error = function(e) {
      climateR::dap(
        URL = data$url2[x],
        varname = var,
        AOI = data[x, ],
        verbose = FALSE
      )
    }, error = function(e) {
      climateR::dap(
        URL = data$url3[x],
        varname = var,
        AOI = data[x, ],
        verbose = FALSE
        )
      })
    }
  # )

  # Join data back together
  gpm_obs = cbind(data, dplyr::bind_rows(l))
  # gpm_obs = dplyr::bind_cols(data, dplyr::bind_rows(l))

  # Return the dataframe
  gpm_obs = gpm_obs %>%
    sf::st_drop_geometry() %>% # drop geometry column to make it dataframe
    dplyr::select('probabilityLiquidPrecipitation')

  return(gpm_obs)

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
