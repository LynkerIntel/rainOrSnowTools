#' QAQC observation data
#'
#' @return dataframe with dupe (Dupe/Pass) and CONUS (NoCONUS, NoData, Pass) flags
#' @importFrom dplyr group_by mutate n case_when `%>%`
#' @examples
#' \dontrun{
#' data_qaqc1 = qaqc_obs(data)
#' }
qaqc_obs = function(data = data){

  data %>%
    dplyr::group_by(id, datetime_utc) %>%
    dplyr::mutate(
      # Checks for dupe time stamps
      observer_count = dplyr::n(),
      dupe_flag = dplyr::case_when(observer_count > 1 ~ "Dupe",
                            TRUE ~ "Pass"),
      observer_count = NULL,
      # Checks for if the observation is within CONUS (study boundary)
      CONUS = dplyr::case_when(
        state == "Alaska" ~ "NoCONUS",
        state == "character(0)" ~ "NoData",
        TRUE ~ "Pass"))  %>%
    ungroup()

}


#' QAQC processed data
#'
#' @return list with 2 dataframes, 1: all flags; 2: filtered to the not complete data
#' @importFrom dplyr mutate case_when any_vars filter_all `%>%`
#' @examples
#' \dontrun{
#' data_qaqc2 = qaqc_processed(data)
#' }

qaqc_processed = function(data = data){

  # Add data flags
  temp_air_snow_max = 10 # max tair in °C for snow
  temp_air_rain_min = -5 # min tair in °C for rain
  rh_thresh = 30
  avgdist_thresh = 2e5 # maximum average distance (200 km)
  closest_thresh = 3e4 # maximum nearest station distance (30 km)
  nstation_thresh = 5 # min number of stations within search radius
  pval_thresh = 0.05 # maximum pval for lapse rate calc

  qaqc <- data %>%
    dplyr::mutate(
      temp_air_flag = dplyr::case_when(
        temp_air >= temp_air_snow_max & phase == "Snow" ~ "WarmSnow",
        temp_air <= temp_air_rain_min &
          phase == "Rain" ~ "CoolRain",
        is.na(temp_air) ~ "NoMet",
        TRUE ~ "Pass"),
      rh_flag = dplyr::case_when(rh < rh_thresh ~ "LowRH",
                                 is.na(rh) ~ "NoMet",
                                 TRUE ~ "Pass"),
      dist_temp_air_flag = dplyr::case_when(
        temp_air_avg_dist >= avgdist_thresh ~ "TooFar",
        is.na(temp_dew_avg_dist) ~ "NoMet",
        TRUE ~ "Pass"),
      dist_temp_dew_flag = dplyr::case_when(
        temp_dew_avg_dist >= avgdist_thresh ~ "TooFar",
        is.na(temp_dew_avg_dist) ~ "NoMet",
        TRUE ~ "Pass"),
      closest_temp_air_flag = dplyr::case_when(
        temp_air_nearest_dist >= closest_thresh ~ "TooFar",
        is.na(temp_air_nearest_dist) ~ "NoMet",
        TRUE ~ "Pass"),
      closest_temp_dew_flag = dplyr::case_when(
        temp_dew_nearest_dist >= closest_thresh ~ "TooFar",
        is.na(temp_dew_nearest_dist) ~ "NoMet",
        TRUE ~ "Pass"),
      nstation_temp_air_flag = dplyr::case_when(
        temp_air_n_stations < nstation_thresh ~ "FewStations",
        is.na(temp_air_n_stations) ~ "NoMet",
        TRUE ~ "Pass"),
      nstation_temp_dew_flag = dplyr::case_when(
        temp_dew_n_stations < nstation_thresh ~ "FewStations",
        is.na(temp_dew_n_stations) ~ "NoMet",
        TRUE ~ "Pass"),
      pval_temp_air_flag = dplyr::case_when(
        temp_air_lapse_var_pval > pval_thresh ~ "PoorLapse",
        is.na(temp_air_lapse_var_pval) ~ "NoMet",
        TRUE ~ "Pass"),
      pval_temp_dew_flag = dplyr::case_when(
        temp_dew_lapse_var_pval > pval_thresh ~ "PoorLapse",
        is.na(temp_dew_lapse_var_pval) ~ "NoMet",
        TRUE ~ "Pass")
    )

  # Note data that have 'NoMet' as part of flag
  # Input into another file for further manual review
  nomets <- qaqc %>%
    dplyr::filter_all(dplyr::any_vars(. %in% "NoMet"))

  # Store all this in a list for QAQC'ed dataframes
  return(list("QAQC" = qaqc,
              "NoMets" = nomets))

}




