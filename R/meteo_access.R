# Functions for accessing, collating, and preprocessing meteorological data
# from various station networks

# Declare global variables to pass R-CMD-check
utils::globalVariables(
  c(".", "DATE", "datetime", "dateTime", "datetime_lst", "datetime_utc_obs", "dist", "timezone_lst",
    "elev", "HourlyDewPointTemperature", "HourlyDryBulbTemperature", "HourlyPrecipitation",
    "HourlyRelativeHumidity", "HourlyWetBulbTemperature", "id", "last_col", "lat", "LATITUDE",
    "lon", "LONGITUDE", "minTime", "name", "nasa_time", "origin_time", "ppt", "ppt2",
    "REPORT_TYPE", "rh", "rh2", "rounded_time", "STATE_NAME", "station", "STATION", "tair",
    "tair2", "tdew", "tdew2", "temp_air", "temp_dew", "temp_wet", "time_gap", "twet2", "utc_valid"
  )
)

# # Declare global variables to pass R-CMD-check
# utils::globalVariables(
#               c(
#               ".", "DATE", "datetime", "dateTime", "datetime_lst",
#               "datetime_utc_obs", "dist",  "elev",
#               "HourlyDewPointTemperature", "HourlyDryBulbTemperature", "HourlyPrecipitation",
#               "HourlyRelativeHumidity", "HourlyWetBulbTemperature",
#               "id", "last_col", "lat",
#               "LATITUDE", "lon", "LONGITUDE", "minTime",
#               "name", "nasa_time", "origin_time",
#               "ppt", "ppt2", "REPORT_TYPE", "rh", "rh2",
#               "rounded_time", "STATE_NAME", "station", "STATION",
#               "tair", "tair2", "tdew", "tdew2",
#               "temp_air", "temp_dew", "temp_wet",
#               "time_gap", "timezone_lst", "twet2",
#               "US_L3NAME", "US_L4NAME", "utc_offset_h",
#               "utc_valid", "value", "weight_raw", "zone"
#               )
#             )

# `%>%` <- dplyr::`%>%`

#' Download and preprocess meteorological data from three station networks
#'
#' @param networks One of "ALL", "HADS", "LCD", or "WCC"
#' @param datetime_utc_obs POSIX-formatted UTC datetime for which data should be gathered
#' @param lon_obs Longitude in decimal degrees
#' @param lat_obs Latitude in decimal degrees
#' @param deg_filter Number of degrees surrounding the point location to which the station search should be limited
#' @param time_thresh_s Time (in seconds) to be added to/subtracted from datetime_utc_obs, thus defining the time extent for the data search
#' @param dist_thresh_m Distance (in meters) that a station must be within to be considered
#'
#' @return a dataframe of meteorological data
#' @export
access_meteo <- function(
    networks,
    datetime_utc_obs,
    lon_obs,
    lat_obs,
    deg_filter=2,
    time_thresh_s=3600,
    dist_thresh_m=100000
    ) {

    # # # EXAMPLE CODE:
    # networks         = met_networks
    # datetime_utc_obs = datetime
    # lon_obs          = lon_obs
    # lat_obs          = lat_obs
    # deg_filter       = degree_filter
    # time_thresh_s=3600
    # dist_thresh_m=100000
    # # met_network = "HADS"
    # datetime = as.POSIXct("2023-01-01 16:00:00", tz = "UTC")
    # meteo <- access_meteo(networks = met_network,
    #                       datetime_utc_obs = datetime,
    #                       lon_obs = lon,
    #                       lat_obs = lat,
    #                       deg_filter = degree_filter)

    # TODOadd function argument that lets user set what variables they want
    # e.g. vars="TA"
    # access_meteo returns a specific set of vars per network

    # Error handling if network not valid
    if(("ALL" %in% networks | "HADS" %in% networks | "LCD" %in% networks |
        "WCC" %in% networks) == FALSE) {
      stop("networks must be ALL, HADS, LCD, or WCC")
    }

    # Error handling if time thresh too long or short
    if (time_thresh_s > 86400 | time_thresh_s < 600) {
      stop("time_thresh_s must be between 600 s and 86400 s")
    }

    # Compute the start and end times for downloading
    datetime_utc_start = datetime_utc_obs - time_thresh_s
    datetime_utc_end = datetime_utc_obs + time_thresh_s

    # Create an empty df to store met data
    met_all <- data.frame()

    # If ALL, add all networks
    if ("ALL" %in% networks) {
      networks = c("HADS", "LCD", "WCC")
    }

    # Access HADS data
    if ("HADS" %in% networks) {
      # Error handling when it comes to no stations reported in the timezones
      tryCatch({
      stations <- station_select(network = "HADS", lon_obs, lat_obs,
                                 deg_filter, dist_thresh_m)
      tmp_met <- download_meteo_hads(datetime_utc_start, datetime_utc_end, stations)
      tmp_met <- preprocess_meteo(network = "HADS", tmp_met)
      met_all <- dplyr::bind_rows(met_all, tmp_met)
      }, error = function(e){})
    }

    # Access LCD data
    if("LCD" %in% networks){
      # Error handling when it comes to no stations reported in the timezones
      tryCatch({
      stations <- station_select(network = "LCD", lon_obs, lat_obs,
                                 deg_filter, dist_thresh_m)
      tmp_met <- download_meteo_lcd(datetime_utc_start, datetime_utc_end, stations)
      tmp_met <- preprocess_meteo(network = "LCD", tmp_met)
      met_all <- dplyr::bind_rows(met_all, tmp_met)
    }, error = function(e){})
    }

    # Access WCC data
    # Access WCC data
    if("WCC" %in% networks){
      # Error handling when it comes to no stations reported in the timezones
      tryCatch({
        stations <- station_select(network = "WCC", lon_obs, lat_obs,
                                   deg_filter, dist_thresh_m)
        tmp_met <- download_meteo_wcc(datetime_utc_start, datetime_utc_end, stations)
        tmp_met <- preprocess_meteo(network = "WCC", tmp_met)
        met_all <- dplyr::bind_rows(met_all, tmp_met)
      }, error = function(e){})
    }

    # met_all  %>% names()

    # if no stations are found, return an empty data frame with column names
    if (nrow(met_all) < 1) {
        # provide empty data frame with column names
        met_all <- data.frame(
          id = character(0),
          datetime = as.POSIXct(character(0), tz = "UTC"),
          temp_air = numeric(0),
          rh = numeric(0),
          temp_dew = numeric(0),
          temp_wet = numeric(0),
          ppt = numeric(0)
        )

    }

    # Return the met_all data frame
    return(met_all)

  }


#' Gather the metadata for meteorological stations
#'
#' @param network network to gather stations from (HADS, LCD, or WCC)
#' @param lon_obs Longitude in decimal degrees
#' @param lat_obs Latitude in decimal degrees
#' @param deg_filter Number of degrees surrounding the point location to which the station search should be limited
#' @param dist_thresh_m Distance (in meters) that a station must be within to be considered
#'
#' @return Dataframe of station metadata
#' @importFrom dplyr filter rowwise mutate ungroup `%>%`
#' @importFrom geosphere distHaversine
#' @export
station_select <- function(network, lon_obs, lat_obs,
                           deg_filter, dist_thresh_m){
  # EXAMPLE CODE:
  # network = "HADS"
  # lat_obs
  # deg_filter
  # dist_thresh_m = dist_thresh_m
  # # station_select(network = "HADS", lon, lat, deg_filter=2, dist_thresh_m=100000)

  # Station metadata provided in sysdata.R
  # hads_meta = HADS metadata
  # lcd_meta = LCD metadata
  # wcc_meta = WCC metadata
  # hads_meta  %>% names()
  # Select stations from the HADS dataset
  if (network == "HADS") {
    stations_tmp <- 
      hads_meta %>%
      dplyr::filter(
        lon >= lon_obs - deg_filter & lon <= lon_obs + deg_filter,
        lat >= lat_obs - deg_filter & lat <= lat_obs + deg_filter
        ) %>%
      dplyr::rowwise() %>%
      dplyr::mutate(dist = geosphere::distHaversine(c(lon_obs, lat_obs), c(lon, lat))) %>%
      dplyr::ungroup() %>%
      dplyr::filter(dist <= dist_thresh_m)
  }

  # Select stations from the LCD dataset
  if(network == "LCD"){
    stations_tmp <- lcd_meta %>%
      dplyr::filter(LONGITUDE >= lon_obs - deg_filter & LONGITUDE <= lon_obs + deg_filter,
                    LATITUDE >= lat_obs - deg_filter & LATITUDE <= lat_obs + deg_filter) %>%
      dplyr::rowwise() %>%
      dplyr::mutate(dist = geosphere::distHaversine(c(lon_obs, lat_obs), c(LONGITUDE, LATITUDE))) %>%
      dplyr::ungroup() %>%
      dplyr::filter(dist <= dist_thresh_m)
  }

  # Select stations from the WCC dataset
  if(network == "WCC"){
    stations_tmp <- wcc_meta %>%
      dplyr::filter(lon >= lon_obs - deg_filter & lon <= lon_obs + deg_filter,
                    lat >= lat_obs - deg_filter & lat <= lat_obs + deg_filter) %>%
      dplyr::rowwise() %>%
      dplyr::mutate(dist = geosphere::distHaversine(c(lon_obs, lat_obs), c(lon, lat))) %>%
      dplyr::ungroup() %>%
      dplyr::filter(dist <= dist_thresh_m)
  }

  # Return the stations dataset
  return(stations_tmp)
}

#' Download meteorological data from HADS
#'
#' @param datetime_utc_start Start of search window as POSIX-formatted UTC datetime
#' @param datetime_utc_end  End of search window as POSIX-formatted UTC datetime
#' @param stations dataframe of station metadata (from station_select)
#' @return dataframe of meteorological data
#' @importFrom dplyr filter rowwise mutate ungroup bind_rows `%>%`
#' @importFrom lubridate year month day minute hour
#' @importFrom readr read_csv cols
#' @export
download_meteo_hads <- function(datetime_utc_start, datetime_utc_end, stations){
   #  ## EXAMPLE CODE:
   #  lon = -105
   #  lat = 40
   #  datetime_start = as.POSIXct("2023-01-01 15:00:00", tz = "UTC")
   #  datetime_end = as.POSIXct("2023-01-01 17:00:00", tz = "UTC")
   #  hads_stations <- station_select(network = "HADS", lon, lat, deg_filter=2, dist_thresh_m=100000)
   #  download_meteo_hads(datetime_start, datetime_end, hads_stations)

  # Specify chunks to download
  # HADS can only serve from 1 calendar year at a time
  # Chunks specify the date ranges in each year
  if(lubridate::year(datetime_utc_start) == lubridate::year(datetime_utc_end)){
    chunks = data.frame(
      chunk = 1,
      year = lubridate::year(datetime_utc_start),
      month1 = lubridate::month(datetime_utc_start),
      day1 = lubridate::day(datetime_utc_start),
      hour1 = lubridate::hour(datetime_utc_start),
      min1 = lubridate::minute(datetime_utc_start),
      month2 = lubridate::month(datetime_utc_end),
      day2 = lubridate::day(datetime_utc_end),
      hour2 = lubridate::hour(datetime_utc_end),
      min2 = lubridate::minute(datetime_utc_end)
    )
  }else{
    chunks = data.frame(
      chunk = c(1,2),
      year = c(lubridate::year(datetime_utc_start),
               lubridate::year(datetime_utc_end)),
      month1 = c(lubridate::month(datetime_utc_start),
                 lubridate::month(datetime_utc_end)),
      day1 = c(lubridate::day(datetime_utc_start),
               lubridate::day(datetime_utc_end)),
      hour1 = c(lubridate::hour(datetime_utc_start),
                0),
      min1 = c(lubridate::minute(datetime_utc_start),
               0),
      month2 = c(lubridate::month(datetime_utc_start),
                 lubridate::month(datetime_utc_end)),
      day2 = c(31,
               lubridate::day(datetime_utc_end)),
      hour2 = c(23,
                lubridate::hour(datetime_utc_end)),
      min2 = c(59,
               lubridate::minute(datetime_utc_end))
    )
  }

  # Build the URL string
  hads_url01_str = "https://mesonet.agron.iastate.edu/cgi-bin/request/hads.py?network="
  hads_url04_str = "&year="
  hads_url06_str = "&month1="
  hads_url08_str = "&day1="
  hads_url10_str = "&hour1="
  hads_url12_str = "&minute1="
  hads_url14_str = "&month2="
  hads_url16_str = "&day2="
  hads_url18_str = "&hour2="
  hads_url20_str = "&minute2="

  # Reset the timeout option so download can finish (default is 60 seconds)
  # getOption('timeout')
  # [1] 60
  # options(timeout = 1000) # this will reset to default when session terminated

  # Empty df to store data
  met <- data.frame()

  # Loop through the options and download HADS data
  for(i in seq_along(chunks$chunk)){
    # Sub loop by years
      # Build the URL parts
      hads_url02_net = as.character(stations[1, "iem_network"])
      hads_url03_sta = paste0("&stations=", paste(stations$stid, collapse = '&stations='))
      hads_url05_yr1 = chunks[i, "year"]
      hads_url07_mo1 = chunks[i, "month1"]
      hads_url09_dy1 = chunks[i, "day1"]
      hads_url11_hr1 = chunks[i, "hour1"]
      hads_url13_mi1 = chunks[i, "min1"]
      hads_url15_mo2 = chunks[i, "month2"]
      hads_url17_dy2 = chunks[i, "day2"]
      hads_url19_hr2 = chunks[i, "hour2"]
      hads_url21_mi2 = chunks[i, "min2"]

      # Concatenate parts into URL
      met.link = paste0(hads_url01_str,
                        hads_url02_net,
                        hads_url03_sta,
                        hads_url04_str,
                        hads_url05_yr1,
                        hads_url06_str,
                        hads_url07_mo1,
                        hads_url08_str,
                        hads_url09_dy1,
                        hads_url10_str,
                        hads_url11_hr1,
                        hads_url12_str,
                        hads_url13_mi1,
                        hads_url14_str,
                        hads_url15_mo2,
                        hads_url16_str,
                        hads_url17_dy2,
                        hads_url18_str,
                        hads_url19_hr2,
                        hads_url20_str,
                        hads_url21_mi2)

      # Download data
      tmp.met <-
        met.link %>%
        readr::read_csv(col_types = readr::cols(.default = "c"))

      # Bind data
      met <- dplyr::bind_rows(met, tmp.met)
  }

  return(met)

}

#' Download meteorological data from LCD
#'
#' @param datetime_utc_start Start of search window as POSIX-formatted UTC datetime
#' @param datetime_utc_end  End of search window as POSIX-formatted UTC datetime
#' @param stations dataframe of station metadata (from station_select)
#'
#' @return dataframe of meteorological data
#' @importFrom dplyr slice pull mutate between select `%>%`
#' @importFrom lubridate with_tz year
#' @importFrom utils read.csv
#' @export
download_meteo_lcd <- function(datetime_utc_start, datetime_utc_end, stations){
  # # EXAMPLE CODE:
  #
  # lon = -105
  # lat = 40
  # datetime_start = as.POSIXct("2023-01-01 15:00:00", tz = "UTC")
  # datetime_end = as.POSIXct("2023-01-01 17:00:00", tz = "UTC")
  # lcd_stations <- station_select(network = "LCD", lon, lat, deg_filter=2, dist_thresh_m=100000)
  # download_meteo_lcd(datetime_start, datetime_end, lcd_stations)

  # Specify the vars
  # TODO: let user select vars
  lcd_vars = "HourlyDewPointTemperature,HourlyDryBulbTemperature,HourlyPrecipitation,HourlyRelativeHumidity,HourlyWetBulbTemperature"

  # Figure out if there is more than 1 time zone to download
  # NOAA serves LCD data in local standard time, NOT UTC
  # Specifying UTC in the download string DOES NOT WORK - it still serves local time
  tzs = unique(stations$timezone_lst)
  n_tz = length(tzs)

  # Create a list of stations by timezone
  stations_by_tz <- split(stations, stations$timezone_lst)

  # Empty df to store data
  met <- data.frame()

  # Loop through n_tz
  # Build URL
  # And download data
  for(i in 1:n_tz){

    # Get start and end dates for tz
    tmp_tz = stations_by_tz[[i]] %>%
      dplyr::slice(1) %>%
      dplyr::pull(timezone_lst)
    datetime_lst_start = lubridate::with_tz(datetime_utc_start,
                                            tzone = tmp_tz)
    datetime_lst_end   = lubridate::with_tz(datetime_utc_end,
                                            tzone = tmp_tz)

    # Build URLS
    lcd_url01_str = "https://www.ncei.noaa.gov/access/services/data/v1?dataset=local-climatological-data&stations="
    lcd_url02_sta = paste(stations_by_tz[[i]]$id, collapse = ',')
    lcd_url03_str = "&startDate="
    lcd_url04_dat = format(datetime_lst_start, "%Y-%m-%dT%H:%M:%S")
    lcd_url05_str = "&endDate="
    lcd_url06_dat = format(datetime_lst_end, "%Y-%m-%dT%H:%M:%S")
    lcd_url07_str = "&dataTypes="
    lcd_url08_var = lcd_vars

    url_lcd = paste0(lcd_url01_str, lcd_url02_sta, lcd_url03_str, lcd_url04_dat,
                     lcd_url05_str, lcd_url06_dat, lcd_url07_str, lcd_url08_var)

    # Download data
    tmp_df <- utils::read.csv(url_lcd)

    # if nrows(tmp_df) = 0, then go to the other URL
    if (nrow(tmp_df) == 0){

      # Redefine the start and ends
      # Hack way to make sure we can go to 12/25 if the date is 12/31
      # TODO: Make this more efficient
      time_thresh_s2 = 518400 # +/- 6 days
      datetime_utc_start2 = datetime_utc_obs - time_thresh_s2
      datetime_utc_end2 = datetime_utc_obs + time_thresh_s2
      datetime_lst_start2 = lubridate::with_tz(datetime_utc_start2,
                                               tzone = tmp_tz)
      datetime_lst_end2 = lubridate::with_tz(datetime_utc_end2,
                                               tzone = tmp_tz)

      if (lubridate::year(datetime_lst_end2) == lubridate::year(datetime_lst_start2)){

        datetime_lst_end2 = datetime_lst_end2

      } else {

        datetime_lst_end2 = datetime_lst_end

      }

      lcd_url04_dat2 = format(datetime_lst_start2, "%Y-%m-%dT%H:%M:%S")
      lcd_url06_dat2 = format(datetime_lst_end2, "%Y-%m-%dT%H:%M:%S")
      url_lcd2 = paste0(lcd_url01_str, lcd_url02_sta, lcd_url03_str, lcd_url04_dat2,
                        lcd_url05_str, lcd_url06_dat2, lcd_url07_str, lcd_url08_var)

      # Download data
      tmp_df <- utils::read.csv(url_lcd2) %>%
        dplyr::mutate(datetime_lst = as.POSIXct(DATE,
                                  format = "%Y-%m-%dT%H:%M:%S",
                                  tz = tmp_tz)) %>%
        # Filter the data to the original dates
        dplyr::filter(dplyr::between(datetime_lst, datetime_lst_start, datetime_lst_end)) %>%
        dplyr::select(-c(datetime_lst))

    } else{

      # If not, just use the existing dataframe
      tmp_df

    }

    # Format datetime
    tmp_df <- tmp_df %>%
      dplyr::mutate(datetime_lst = as.POSIXct(DATE,
                                              format = "%Y-%m-%dT%H:%M:%S",
                                              tz = tmp_tz),
                    datetime = lubridate::with_tz(datetime_lst,
                                                  tz = "UTC"))

    # Bind data
    met <- dplyr::bind_rows(met, tmp_df)
  }

  # Return the data
  return(met)
}

#' Download meteorological data from WCC
#'
#' @param datetime_utc_start Start of search window as POSIX-formatted UTC datetime
#' @param datetime_utc_end  End of search window as POSIX-formatted UTC datetime
#' @param stations dataframe of station metadata (from station_select)
#'
#' @return dataframe of meteorological data
#' @importFrom dplyr case_when mutate slice pull bind_rows `%>%`
#' @importFrom lubridate with_tz hours days seconds date
#' @importFrom plyr ldply
#' @importFrom tidyr pivot_longer pivot_wider separate
#' @importFrom utils read.delim
#' @export
download_meteo_wcc <- function(datetime_utc_start, datetime_utc_end, stations){

  # # EXAMPLE CODE:
  # lon = -105
  # lat = 40
  # datetime_utc_start = as.POSIXct("2023-01-01 15:00:00", tz = "UTC")
  # datetime_utc_end = as.POSIXct("2023-01-01 17:00:00", tz = "UTC")
  # wcc_stations <- station_select(network = "WCC", lon, lat,  deg_filter=2, dist_thresh_m=100000)
  # download_meteo_wcc(datetime_start, datetime_end, wcc_stations)

  stations = stations %>%
    dplyr::mutate(network.ab = dplyr::case_when(network == "snotel" ~ "sntl",
                                                network == "snotelt" ~ "sntlt",
                                                TRUE ~ network))

  # Adjust timezones... all western SNOTEL stations give times in PST, but all other locations are local standard time
  tzs = unique(stations$timezone_lst)
  n_tz = length(tzs)

  # Create a list of stations by timezone
  stations_by_tz <- split(stations, stations$timezone_lst)

  # Empty df to store data
  met <- data.frame()

  # Loop through stations by time zone and wyears
  # Build URL and download data
  for(i in 1:n_tz){

    # Get start and end dates for tz
    tmp_tz = stations_by_tz[[i]] %>%
      dplyr::slice(1) %>%
      dplyr::pull(timezone_lst)

    datetime_lst_start = lubridate::with_tz(datetime_utc_start,
                                            tzone = tmp_tz)
    datetime_lst_end   = lubridate::with_tz(datetime_utc_end,
                                            tzone = tmp_tz)

    # Create chunks based on if start/end dates are the same day
    if(lubridate::date(datetime_lst_start) == lubridate::date(datetime_lst_end)){

      hrs <- c(seq(from = as.POSIXct(datetime_lst_start, format = "%Y-%m-%d %H:%M:%S"),
                   to = as.POSIXct(datetime_lst_end, format = "%Y-%m-%d %H:%M:%S"),
                   by = "hour")) %>%
        format("%H") %>%
        as.integer()

      chunks = data.frame(
        chunk = 1,
        date1 = format(datetime_lst_start, "%Y-%m-%d"),
        date2 = format(datetime_lst_end, "%Y-%m-%d"),
        hours = paste("H%7C", hrs, sep = "", collapse = ",")
      )
      # If not, create 2 URL chunks to get hours parsed by:
      # Start date H - H23
      # End date H00 - end date H
    }else{

      hrs1 <- c(seq(from = as.POSIXct(datetime_lst_start, format = "%Y-%m-%d %H:%M:%S"),
                    to = as.POSIXct(datetime_lst_start, format = "%Y-%m-%d %H:%M:%S") +
                      # Very convoluted way
                      lubridate::days(1) - lubridate::hours(format(datetime_lst_start, "%H")) - lubridate::seconds(1),
                    by = "hour")) %>%
        format("%H") %>%
        as.integer()

      hrs2 <- c(seq(from = as.POSIXct(as.Date(datetime_lst_end), tz = "UTC"),
                    to = as.POSIXct(datetime_lst_end, format = "%Y-%m-%d %H:%M:%S"),
                    by = "hour")) %>%
        format("%H") %>%
        as.integer()

      chunks = data.frame(
        chunk = c(1,2),
        date1 = c(format(datetime_lst_start, "%Y-%m-%d"),
                  format(datetime_lst_end, "%Y-%m-%d")),
        date2 = c(format(datetime_lst_start, "%Y-%m-%d"),
                  format(datetime_lst_end, "%Y-%m-%d")),
        hours = c(paste("H%7C", hrs1, sep = "", collapse = ","),
                  paste("H%7C", hrs2, sep = "", collapse = ","))
      )
    }

    # Create list for collecting data for each station in each time zone
    tmp.station <- list()

    # Loop through the options and download WCC data
    for(c in seq_along(chunks$chunk)){

      # Build URLS
      wcc_url01_str = "https://wcc.sc.egov.usda.gov/reportGenerator/view_csv/customMultiTimeSeriesGroupByStationReport/hourly/start_of_period/"
      wcc_url02_sta = paste(stations_by_tz[[i]]$`station.id`,":",stations_by_tz[[i]]$`state`,":",
                            stations_by_tz[[i]]$`network.ab`, collapse = "%7C", sep = "")
      wcc_url03_str = "%7Cid=%22%22%7Cname/"
      wcc_url04_dat = chunks[c, "date1"]
      wcc_url05_dat = chunks[c, "date2"]
      wcc_url06_tim = chunks[c, "hours"]
      wcc_url07_val = "stationId,TOBS::value,RHUM::value,DPTP::value" # Pick variables that we want in final dataframe
      # (might need to change if we want end user to pick their own vars)

      url_wcc = paste0(wcc_url01_str, wcc_url02_sta, wcc_url03_str, wcc_url04_dat, ",", wcc_url05_dat, ":",
                       wcc_url06_tim, "/", wcc_url07_val)

      # Download data
      if (length(stations_by_tz[[i]]$`station.id`) == 1){
        # Download data, apply col names, and store into list
        tmp.station[[as.character(stations_by_tz[[i]]$`station.id`)]] <- utils::read.delim(url_wcc, header = T, comment.char = '#', sep = "\t") %>%
          tidyr::separate(colnames(.)[1], c("date", "tair", "rh", "tdew"), sep = ",")

      } else{
        n = length(stations_by_tz[[i]]$`station.id`)
        id = stations_by_tz[[i]]$`station.id`
        # Set col names
        cols = c("tair", "rh", "tdew")
        # Create the col names and id them with the station ID
        # Ex) tair1100 (var + station ID)
        colvars = as.vector(t(as.matrix(sapply(cols, paste, id, sep = ""))))

        # Download data and apply col names
        tmp <- utils::read.delim(url_wcc, header = T, comment.char = '#', sep = "\t") %>%
          tidyr::separate(colnames(.)[1], c("date", colvars), sep = ",") %>%
          # This takes the data into long form, separates the var name station ID
          tidyr::pivot_longer(
            cols = !date,
            names_to = c("var", "station"),
            names_pattern = "([A-Za-z]+)(\\d+)",
            values_to = "val") %>%
          # Sets up the dataframe to standard format
          tidyr::pivot_wider(., names_from = "var", values_from = "val")

        # Store output into list
        tmp.station <- lapply(split(tmp, tmp$station, drop = TRUE), subset, select = -station)
      }

      # Bind data from temporary list into a single data frame and format datetime
      tmp.df <- plyr::ldply(tmp.station, dplyr::bind_rows) %>%
        dplyr::mutate(datetime_lst = as.POSIXct(date,
                                                format = "%Y-%m-%d %H:%M",
                                                tz = tmp_tz),
                      datetime = lubridate::with_tz(datetime_lst,
                                                    tz = "UTC"))
    }
    met <- dplyr::bind_rows(met, tmp.df)

  }

  # Return the data
  return(met)

}

#' Preprocess met data (add datetime, put in common format)
#'
#' @param network network of data to process (HADS, LCD, or WCC)
#' @param tmp_met dataframe of meteorological data (from download_meteo_*)
#'
#' @return processed dataframe of met data
#' @importFrom dplyr select filter mutate across case_when `%>%`
#' @importFrom lubridate with_tz hours days seconds date
#' @export
preprocess_meteo <- function(network, tmp_met){

  ## EXAMPLE CODE:
  # lon = -105
  # lat = 40
  # datetime_start = as.POSIXct("2023-01-01 15:00:00", tz = "UTC")
  # datetime_end = as.POSIXct("2023-01-01 17:00:00", tz = "UTC")
  # lcd_stations <- station_select(network = "LCD", lon, lat,  deg_filter=2, dist_thresh_m=100000)
  # lcd_met <- download_meteo_lcd(datetime_start, datetime_end, lcd_stations)
  # preprocess_meteo("LCD", lcd_met)

  # Process HADS data
  if(network == "HADS"){

    # Identify columns and new names
    lookup <- c(temp_air = "TAIRGZ", temp_dew = "TDIRGZ", rh = "XRIRGZ",
                temp_air = "TAIRGZZ", temp_dew = "TDIRGZZ", rh = "XRIRGZZ")

    # Down-select columns and rename
    tmp_met <- tmp_met %>%
      dplyr::select(id = station, datetime = utc_valid,
                    tidyselect::any_of(lookup))

    # Filter to rows only with valid tair measurements
    tmp_met <- tmp_met %>%
      dplyr::filter(!is.na(temp_air))

    # Compute number of columns and transform char data to numeric
    n_cols = length(tmp_met)
    tmp_met <- tmp_met %>%
      dplyr::mutate(dplyr::across(3:n_cols, as.numeric))

    # Convert UTC time string to POSIX UTC
    tmp_met$datetime <- as.POSIXct(tmp_met$datetime,
                                 format = "%Y-%m-%d %H:%M:%S",
                                 tz = "UTC")

    # Convert temp from F to C
    tmp_met <- tmp_met %>%
      dplyr::mutate(dplyr::across(dplyr::contains('temp_'), ~ f_to_c(.)))
  }

  # Process LCD data
  if(network == "LCD"){
    # Select only the appropriate columns and rename
    # But first filter to only the FM-15 reports
    tmp_met <- tmp_met %>%
      dplyr::filter(REPORT_TYPE == "FM-15") %>%
      dplyr::select(id = STATION, datetime,
                    tair = HourlyDryBulbTemperature, tdew = HourlyDewPointTemperature,
                    rh = HourlyRelativeHumidity, twet = HourlyWetBulbTemperature,
                    ppt = HourlyPrecipitation)

    # Convert any data points containing an "s" to NA
    # These don't pass the stations QC checks
    tmp_met <- tmp_met %>%
      dplyr::mutate(
        tair2 = dplyr::case_when(grepl("s", tair) ~ NA_real_,
                          TRUE ~ as.numeric(as.character(tair))),
        twet2 = dplyr::case_when(grepl("s", twet) ~ NA_real_,
                          TRUE ~ as.numeric(as.character(twet))),
        tdew2 = dplyr::case_when(grepl("s", tdew) ~ NA_real_,
                          TRUE ~ as.numeric(as.character(tdew))),
        ppt2  = dplyr::case_when(grepl("s", ppt) ~ NA_real_,
                          TRUE ~ as.numeric(as.character(ppt))),
        rh2   = dplyr::case_when(grepl("s", rh) ~ NA_real_,
                          TRUE ~ as.numeric(as.character(rh)))
      ) %>%
      dplyr::mutate(ppt2 = ifelse(ppt == "T", 0.0001, ppt2))

    # Convert temp to celsius and ppt to mm
    tmp_met <- tmp_met %>%
      dplyr::select(id, datetime,
             temp_air = tair2, temp_dew = tdew2, temp_wet = twet2, rh = rh2, ppt = ppt2) %>%
      dplyr::mutate(temp_air = f_to_c(temp_air),
                    temp_dew = f_to_c(temp_dew),
                    temp_wet = f_to_c(temp_wet),
                    ppt = in_to_mm(ppt))
  }

  # Process WCC data
  if(network == "WCC"){

    tmp_met <- tmp_met %>%
      dplyr::select(c(id = '.id', datetime,
                      temp_air = tair,
                      temp_dew = tdew,
                      rh)) %>%
      dplyr::mutate(dplyr::across(3:last_col(), as.numeric)) %>%
      dplyr::mutate(temp_air = f_to_c(temp_air),
                    temp_dew = f_to_c(temp_dew))

  }

  # Convert all station ids to character
  tmp_met <- tmp_met %>%
    dplyr::mutate(id = as.character(id))

  # Return the data
  tmp_met
}
