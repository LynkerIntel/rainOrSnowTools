#' QAQC observation data
#'
#' @param data Dataframe of observation data
#'
#' @return Dataframe with dupe (Dupe/Pass) and CONUS (NoCONUS, NoData, Pass) flags
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
      observer_count = NULL) %>%
    dplyr::ungroup() %>%
    dplyr::mutate(
      # Checks for if the observation is within CONUS (study boundary)
      CONUS = dplyr::case_when(
        state == "Alaska" ~ "NoCONUS",
        state == "character(0)" ~ "NoData",
        TRUE ~ "Pass"))

}


#' QAQC processed data
#'
#' @param data Dataframe of processed observation data
#' @param snow_max_tair Max tair in °C for snow
#' @param rain_max_tair Min tair in °C for rain
#' @param rh_min Min for RH %
#' @param max_avgdist_station Max average distance (m)
#' @param max_closest_station Max nearest station distance (m)
#' @param min_n_station Min number of stations within search radius
#' @param pval_max Max p-value for the lapse rate calc
#'
#' @return List with 2 dataframes, 1: All flags; 2: Filtered to just incomplete data
#' @importFrom dplyr mutate case_when any_vars filter_all `%>%`
#' @examples
#' \dontrun{
#' data = data_processed
#' snow_max_tair = 10,
#' rain_max_tair = -5,
#' rh_min = 30,
#' max_avgdist_station = 2e5,
#' max_closest_station = 3e4,
#' min_n_station = 5,
#' pval_max = 0.05
#' data_qaqc2 = qaqc_processed(data = data,
#'                            snow_max_tair = snow_max_tair,
#'                            rain_max_tair = rain_max_tair,
#'                            rh_min = rh_min,
#'                            max_avgdist_station = max_avgdist_station,
#'                            max_closest_station = max_closest_station,
#'                            min_n_station = min_n_station,
#'                            pval_max = pval_max)
#' }

qaqc_processed = function(data = data,
                          snow_max_tair = 10,
                          rain_max_tair = -5,
                          rh_min = 30,
                          max_avgdist_station = 2e5,
                          max_closest_station = 3e4,
                          min_n_station = 5,
                          pval_max = 0.05
                          ){

  # Add data flags
  temp_air_snow_max = snow_max_tair
  temp_air_rain_min = rain_max_tair
  rh_thresh = rh_min
  avgdist_thresh = max_avgdist_station
  closest_thresh = max_closest_station
  nstation_thresh = min_n_station
  pval_thresh = pval_max

  qaqc <- data %>%
    dplyr::mutate(
      temp_air_flag = dplyr::case_when(
        temp_air >= temp_air_snow_max &
          phase == "Snow" ~ "WarmSnow",
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

  # Store all this in a list for QAQC'ed outputs
  return(list("QAQC" = qaqc,
              "NoMets" = nomets))

}




