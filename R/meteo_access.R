`%>%` <- dplyr::`%>%`

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
#'
#' @examples
#' met_network = "HADS"
#' datetime = as.POSIXct("2023-01-01 16:00:00", tz = "UTC")
#' lon = -105
#' lat = 40
#' degree_filter = 1
#' meteo <- access_meteo(networks = met_network,
#'                       datetime_utc_obs = datetime,
#'                       lon_obs = lon,
#'                       lat_obs = lat,
#'                       deg_filter = degree_filter)
access_meteo <-
  function(networks, datetime_utc_obs, lon_obs, lat_obs,
           deg_filter=2, time_thresh_s=3600, dist_thresh_m=100000){

    # TODO: add function argument that lets user set what variables they want
    # e.g. vars="TA"
    # access_meteo returns a specific set of vars per network

    # Error handling if network not valid
    if(("ALL" %in% networks | "HADS" %in% networks | "LCD" %in% networks |
        "WCC" %in% networks) == FALSE) {
      stop("networks must be ALL, HADS, LCD, or WCC")
    }

    # Error handling if time thresh too long or short
    if(time_thresh_s > 86400 | time_thresh_s < 600) {
      stop("time_thresh_s must be between 600 s and 86400 s")
    }

    # Compute the start and end times for downloading
    datetime_utc_start = datetime_utc_obs - time_thresh_s
    datetime_utc_end = datetime_utc_obs + time_thresh_s

    # Create an empty df to store met data
    met_all <- data.frame()

    # If ALL, add all networks
    if("ALL" %in% networks){
      networks = c("HADS", "LCD", "WCC")
    }

    # Access HADS data
    if("HADS" %in% networks){
      stations <- station_select(network = "HADS", lon_obs, lat_obs,
                                 deg_filter, dist_thresh_m)
      tmp_met <- download_meteo_hads(datetime_utc_start, datetime_utc_end, stations)
      tmp_met <- preprocess_meteo(network = "HADS", tmp_met)
      met_all <- dplyr::bind_rows(met_all, tmp_met)
    }

    # Access LCD data
    if("LCD" %in% networks){
      stations <- station_select(network = "LCD", lon_obs, lat_obs,
                                 deg_filter, dist_thresh_m)
      tmp_met <- download_meteo_lcd(datetime_utc_start, datetime_utc_end, stations)
      tmp_met <- preprocess_meteo(network = "LCD", tmp_met)
      met_all <- dplyr::bind_rows(met_all, tmp_met)
    }

    # Access WCC data
    if("WCC" %in% networks){
      stations <- station_select(network = "WCC", lon_obs, lat_obs,
                                 deg_filter, dist_thresh_m)
      tmp_met <- download_meteo_wcc(datetime_utc_start, datetime_utc_end, stations)
      tmp_met <- preprocess_meteo(network = "WCC", tmp_met)
      met_all <- dplyr::bind_rows(met_all, tmp_met)
    }

    # Return the met_all data frame
    met_all

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
#' @export
#'
#' @examples
#' lon = -105
#' lat = 40
#' station_select(network = "HADS", lon, lat,
#'                   deg_filter=2, dist_thresh_m=100000)
station_select <- function(network, lon_obs, lat_obs,
                           deg_filter, dist_thresh_m){
  # Station metadata provided in sysdata.R
  # hads_meta = HADS metadata
  # lcd_meta = LCD metadata
  # wcc_meta = WCC metadata

  # Select stations from the HADS dataset
  if(network == "HADS"){
    stations_tmp <- hads_meta %>%
      dplyr::filter(lon >= lon_obs - deg_filter & lon <= lon_obs + deg_filter,
             lat >= lat_obs - deg_filter & lat <= lat_obs + deg_filter) %>%
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
  stations_tmp
}

#' Download meteorological data from HADS
#'
#' @param datetime_utc_start Start of search window as POSIX-formatted UTC datetime
#' @param datetime_utc_end  End of search window as POSIX-formatted UTC datetime
#' @param stations dataframe of station metadata (from station_select)
#'
#' @return dataframe of meteorological data
#'
#' @examples
#' lon = -105
#' lat = 40
#' datetime_start = as.POSIXct("2023-01-01 15:00:00", tz = "UTC")
#' datetime_end = as.POSIXct("2023-01-01 17:00:00", tz = "UTC")
#' hads_stations <- station_select(network = "HADS", lon, lat,
#'                    deg_filter=2, dist_thresh_m=100000)
#' download_meteo_hads(datetime_start, datetime_end, hads_stations)
download_meteo_hads <- function(datetime_utc_start, datetime_utc_end, stations){

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
      tmp.met <- met.link %>% readr::read_csv(col_types = readr::cols(.default = "c"))

      # Bind data
      met <- dplyr::bind_rows(met, tmp.met)
  }
  met
}

#' Download meteorological data from LCD
#'
#' @param datetime_utc_start Start of search window as POSIX-formatted UTC datetime
#' @param datetime_utc_end  End of search window as POSIX-formatted UTC datetime
#' @param stations dataframe of station metadata (from station_select)
#'
#' @return dataframe of meteorological data
#'
#' @examples
#' lon = -105
#' lat = 40
#' datetime_start = as.POSIXct("2023-01-01 15:00:00", tz = "UTC")
#' datetime_end = as.POSIXct("2023-01-01 17:00:00", tz = "UTC")
#' lcd_stations <- station_select(network = "LCD", lon, lat,
#'                    deg_filter=2, dist_thresh_m=100000)
#' download_meteo_lcd(datetime_start, datetime_end, lcd_stations)
download_meteo_lcd <- function(datetime_utc_start, datetime_utc_end, stations){

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
    tmp_df <- read.csv(url_lcd)

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
  met
}


#' Preprocess met data (add datetime, put in common format)
#'
#' @param network network of data to process (HADS, LCD, or WCC)
#' @param tmp_met dataframe of meteorological data (from download_meteo_*)
#'
#' @return processed dataframe of met data
#'
#' @examples
#' lon = -105
#' lat = 40
#' datetime_start = as.POSIXct("2023-01-01 15:00:00", tz = "UTC")
#' datetime_end = as.POSIXct("2023-01-01 17:00:00", tz = "UTC")
#' lcd_stations <- station_select(network = "LCD", lon, lat,
#'                    deg_filter=2, dist_thresh_m=100000)
#' lcd_met <- download_meteo_lcd(datetime_start, datetime_end, lcd_stations)
#' preprocess_meteo("LCD", lcd_met)
preprocess_meteo <- function(network, tmp_met){

  # Process HADS data
  if(network == "HADS"){

    # Identify columns and new names
    lookup <- c(temp_air = "TAIRGZZ", temp_dew = "TDIRGZZ", rh = "XRIRGZZ")

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
      dplyr::mutate(across(3:n_cols, as.numeric))

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

  # Return the data
  tmp_met
}
