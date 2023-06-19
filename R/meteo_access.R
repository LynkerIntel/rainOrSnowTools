`%>%` <- dplyr::`%>%`

access_meteo <-
  function(networks, datetime_utc_obs, lon_obs, lat_obs,
           deg_filter=2, time_thresh_s=3600, dist_thresh_m=100000){

    # TODO: add function argument that lets user set what variables they want
    # e.g. vars="TA"
    # access_meteo returns a specific set of vars per network

    if(("ALL" %in% networks | "HADS" %in% networks | "LCD" %in% networks |
        "WCC" %in% networks) == FALSE) {
      stop("networks must be ALL, HADS, LCD, or WCC")
    }

    if(time_thresh_s > 86400 | time_thresh_s < 600) {
      stop("time_thresh_s must be between 600 s and 86400 s")
    }

    # Compute the start and end times for downloading
    datetime_utc_start = datetime_utc_obs - time_thresh_s
    datetime_utc_end = datetime_utc_obs + time_thresh_s

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
    }

    # Access LCD data
    if("LCD" %in% networks){

    }

    # Access WCC data
    if("WCC" %in% networks){

    }
    tmp_met

  }


station_select <- function(network, lon_obs, lat_obs,
                           deg_filter, dist_thresh_m){

  # Station metadata added
  # HADS
    #Use the mros_hads_metadata_scrape.R script
    # hads_meta <- read.csv("https://raw.githubusercontent.com/SnowHydrology/MountainRainOrSnow/main/data/metadata/hads_station_metadata_US.csv") %>%
    # dplyr::filter(substr(iem_network, start = 4, stop = 6) == "DCP")
    # usethis::use_data(hads_meta, internal = TRUE)

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
  stations_tmp
}

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

select_meteo <- function(network, tmp_met){
  if(network == "HADS"){

    # Identify columns and new names
    lookup <- c(tair = "TAIRGZZ", tdew = "TDIRGZZ", rh = "XRIRGZZ")

    # Down-select columns and rename
    tmp_met <- tmp_met %>%
      dplyr::select(station, utc_valid, tidyselect::any_of(lookup))

    # Compute number of columns and transform char data to numeric
    n_cols = length(tmp_met)
    tmp_met <- tmp_met %>%
      dplyr::mutate(across(3:n_cols, as.numeric))
  }
}

preprocess_meteo <- function(network, tmp_met){

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
  tmp_met
}
