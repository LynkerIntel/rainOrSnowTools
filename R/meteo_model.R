# Declare global variables to pass R-CMD-check
utils::globalVariables(
  c("dist", "elev", "lat", "lon", "temp_air", "temp_dew", "rh", "weight_raw")
)

# # Get the pipe
# `%>%` <- dplyr::`%>%` # add dplyr pipe

#' Model climate data for an ID, at a location/elevation/time
#'
#' @param id character or integer
#' @param lon_obs numeric, longitude of observation
#' @param lat_obs numeric, latitude of observation
#' @param elevation numeric
#' @param datetime_utc Date or character
#' @param meteo_df data.frame
#' @param meta_df data.frame
#' @param n_station_thresh numeric, number of stations threshold
#'
#' @return data.frame, maybe with a unique ID for joining...
#' @importFrom dplyr left_join filter rowwise mutate arrange pull bind_cols case_when `%>%`
#' @importFrom stats lm
#' @importFrom humidity dewpoint relhum wetbulb
#' @importFrom geosphere distHaversine
#' @export
model_meteo <- function(id,
                        lon_obs,
                        lat_obs,
                        elevation,
                        datetime_utc,
                        meteo_df,
                        meta_df,
                        n_station_thresh=5
                        ){

  # Assign the constant lapse rate of -0.005 K/m from Girotto et al. (2014)
  t_lapse_const = -0.005
  td_lapse_const = -0.002

  # TODO: some of the scripting in model_meteo can be broken down further
  # - into reusable, more generic functions
  # - Output a data frame
  # - With a unique id for joining?

  # Join the metadata to the meteo data
  df <- dplyr::left_join(meteo_df, meta_df,
                         by = "id") %>%
    dplyr::filter(!is.na(elev) & !is.na(lat) & !is.na(lon))

  # We need distance between obs and stations
  df <- df %>%
    dplyr::rowwise() %>%
    dplyr::mutate(dist = geosphere::distHaversine(c(lon_obs, lat_obs), c(lon, lat)))

  # We need elevation for obs and stations

  ##############################################################################
  # MODEL AIR TEMPERATURE
  ##############################################################################

  # Filter to just air temperature obs
  df_tmp <- df %>%
    dplyr::filter(!is.na(temp_air))

  # Model air temp if valid.ids >= threshold
  if(length(df_tmp$id) >= n_station_thresh){
    # Compute lapse rate from all stations using linear regression
    lapse_fit <- lm(temp_air ~ elev, df_tmp)
    lapse = lapse_fit$coefficients[2] %>% as.numeric()
    lapse_r2 = summary(lapse_fit)$r.squared
    lapse_pval = summary(lapse_fit)$coefficients[2,4]
    n_stations = length(df_tmp$id)
    avg_time = mean(df_tmp$time_gap) %>% as.numeric()
    avg_dist = mean(df_tmp$dist)

    # Get info on nearest station
    df_tmp <- dplyr::arrange(df_tmp, dist)
    nearest_id = df_tmp[1, "id"] %>% dplyr::pull()
    nearest_elev = df_tmp[1, "elev"] %>% dplyr::pull()
    nearest_dist = df_tmp[1, "dist"] %>% dplyr::pull()
    nearest_temp_air = df_tmp[1, "temp_air"] %>% dplyr::pull()

    # Compute the IDW weights
    df_tmp <- df_tmp %>%
      dplyr::mutate(weight_raw = 1/(dist^2)) # calculate raw weight (1/distance squared)
    weight_tot = sum(df_tmp$weight_raw, na.rm = T) # total weights
    df_tmp <- df_tmp %>%
      dplyr::mutate(weight_norm = weight_raw/weight_tot)

    #Estimate with IDW and constant/variable lapse rates
    df_tmp <- df_tmp %>%
      dplyr::mutate(temp_air_sealevel_const = temp_air + (t_lapse_const * (0 - elev)),
             temp_air_sealevel_var = temp_air + (lapse * (0 - elev)))

    # Compute the air temperature at the observation point
    temp_air_idw_lapse_const =
      sum(df_tmp$weight_norm * df_tmp$temp_air_sealevel_const, na.rm = T) +
      (t_lapse_const * elevation)
    temp_air_idw_lapse_var =
      sum(df_tmp$weight_norm * df_tmp$temp_air_sealevel_var, na.rm = T) +
      (lapse * elevation)
    temp_air_nearest_site_const =
      (elevation - nearest_elev) * t_lapse_const + nearest_temp_air
    temp_air_nearest_site_var =
      (elevation - nearest_elev) * lapse + nearest_temp_air

    # Put everything into a single-row data frame
    modeled_met <-
      data.frame(id = id,
                 temp_air_idw_lapse_const = temp_air_idw_lapse_const,
                 temp_air_idw_lapse_var = temp_air_idw_lapse_var,
                 temp_air_nearest_site_const = temp_air_nearest_site_const,
                 temp_air_nearest_site_var = temp_air_nearest_site_var,
                 temp_air_avg_obs = mean(df_tmp$temp_air, na.rm = T),
                 temp_air_min_obs = min(df_tmp$temp_air, na.rm = T),
                 temp_air_max_obs = max(df_tmp$temp_air, na.rm = T),
                 temp_air_lapse_var = lapse,
                 temp_air_lapse_var_r2 = lapse_r2,
                 temp_air_lapse_var_pval = lapse_pval,
                 temp_air_n_stations = n_stations,
                 temp_air_avg_time_gap = avg_time,
                 temp_air_avg_dist = avg_dist,
                 temp_air_nearest_id = nearest_id ,
                 temp_air_nearest_elev = nearest_elev,
                 temp_air_nearest_dist = nearest_dist,
                 temp_air_nearest = nearest_temp_air)
  }else{
    modeled_met <-
      data.frame(id = id,
                 temp_air_idw_lapse_const = NA,
                 temp_air_idw_lapse_var = NA,
                 temp_air_nearest_site_const = NA,
                 temp_air_nearest_site_var = NA,
                 temp_air_avg_obs = NA,
                 temp_air_min_obs = NA,
                 temp_air_max_obs = NA,
                 temp_air_lapse_var = NA,
                 temp_air_lapse_var_r2 = NA,
                 temp_air_lapse_var_pval = NA,
                 temp_air_n_stations = length(df_tmp$id),
                 temp_air_avg_time_gap = NA,
                 temp_air_avg_dist = NA,
                 temp_air_nearest_id = NA ,
                 temp_air_nearest_elev = NA,
                 temp_air_nearest_dist = NA,
                 temp_air_nearest = NA)
  }

  ##############################################################################
  # MODEL WET BULB and DEW POINT TEMPERATURE and RELATIVE HUMIDITY
  ##############################################################################

  # Compute temp_dew when rh and temp_air exist
  df <- df %>%
    dplyr::mutate(temp_dew =ifelse(!is.na(temp_dew), temp_dew, humidity::dewpoint(temp_air, rh)))
    # dplyr::mutate(temp_dew = dplyr::case_when(!is.na(temp_dew) ~ temp_dew,   # Use observed TDEW when it exists
    #                                           TRUE ~ humidity::dewpoint(temp_air, rh)))

  # Filter to just data with valid dew point temperature obs
  df_tmp <- df %>%
    dplyr::filter(!is.na(temp_dew))

  # Model dew point temp if valid.ids >= threshold
  if(length(df_tmp$id) >= n_station_thresh){
    # Compute lapse rate from all stations using linear regression
    lapse_fit <- stats::lm(temp_dew ~ elev, df_tmp)
    lapse = lapse_fit$coefficients[2] %>% as.numeric()
    lapse_r2 = summary(lapse_fit)$r.squared
    lapse_pval = summary(lapse_fit)$coefficients[2,4]
    n_stations = length(df_tmp$id)
    avg_time = mean(df_tmp$time_gap) %>% as.numeric()
    avg_dist = mean(df_tmp$dist)

    # Get info on nearest station
    df_tmp <- dplyr::arrange(df_tmp, dist)
    nearest_id = df_tmp[1, "id"] %>% dplyr::pull()
    nearest_elev = df_tmp[1, "elev"] %>% dplyr::pull()
    nearest_dist = df_tmp[1, "dist"] %>% dplyr::pull()
    nearest_temp_dew = df_tmp[1, "temp_dew"] %>% dplyr::pull()

    # Compute the IDW weights
    df_tmp <- df_tmp %>%
      dplyr::mutate(weight_raw = 1/(dist^2)) # calculate raw weight (1/distance squared)
    weight_tot = sum(df_tmp$weight_raw, na.rm = T) # total weights
    df_tmp <- df_tmp %>%
      dplyr::mutate(weight_norm = weight_raw/weight_tot)

    #Estimate with IDW and constant/variable lapse rates
    df_tmp <- df_tmp %>%
      dplyr::mutate(temp_dew_sealevel_const = temp_dew + (td_lapse_const * (0 - elev)),
                    temp_dew_sealevel_var = temp_dew + (lapse * (0 - elev)))

    # Compute the air temperature at the observation point
    temp_dew_idw_lapse_const =
      sum(df_tmp$weight_norm * df_tmp$temp_dew_sealevel_const, na.rm = T) +
      (td_lapse_const * elevation)
    temp_dew_idw_lapse_var =
      sum(df_tmp$weight_norm * df_tmp$temp_dew_sealevel_var, na.rm = T) +
      (lapse * elevation)
    temp_dew_nearest_site_const =
      (elevation - nearest_elev) * td_lapse_const + nearest_temp_dew
    temp_dew_nearest_site_var =
      (elevation - nearest_elev) * lapse + nearest_temp_dew

    # Put everything into a single-row data frame
    modeled_met <-
      dplyr::bind_cols(
        modeled_met,
        data.frame(temp_dew_idw_lapse_const = temp_dew_idw_lapse_const,
                   temp_dew_idw_lapse_var = temp_dew_idw_lapse_var,
                   temp_dew_nearest_site_const = temp_dew_nearest_site_const,
                   temp_dew_nearest_site_var = temp_dew_nearest_site_var,
                   temp_dew_avg_obs = mean(df_tmp$temp_dew, na.rm = T),
                   temp_dew_min_obs = min(df_tmp$temp_dew, na.rm = T),
                   temp_dew_max_obs = max(df_tmp$temp_dew, na.rm = T),
                   temp_dew_lapse_var = lapse,
                   temp_dew_lapse_var_r2 = lapse_r2,
                   temp_dew_lapse_var_pval = lapse_pval,
                   temp_dew_n_stations = n_stations,
                   temp_dew_avg_time_gap = avg_time,
                   temp_dew_avg_dist = avg_dist,
                   temp_dew_nearest_id = nearest_id ,
                   temp_dew_nearest_elev = nearest_elev,
                   temp_dew_nearest_dist = nearest_dist,
                   temp_dew_nearest = nearest_temp_dew)
      )
  }else{
    modeled_met <-
      dplyr::bind_cols(
        modeled_met,
        data.frame(temp_dew_idw_lapse_const = NA,
                   temp_dew_idw_lapse_var = NA,
                   temp_dew_nearest_site_const = NA,
                   temp_dew_nearest_site_var = NA,
                   temp_dew_avg_obs = NA,
                   temp_dew_min_obs = NA,
                   temp_dew_max_obs = NA,
                   temp_dew_lapse_var = NA,
                   temp_dew_lapse_var_r2 = NA,
                   temp_dew_lapse_var_pval = NA,
                   temp_dew_n_stations = length(df_tmp$id),
                   temp_dew_avg_time_gap = NA,
                   temp_dew_avg_dist = NA,
                   temp_dew_nearest_id = NA ,
                   temp_dew_nearest_elev = NA,
                   temp_dew_nearest_dist = NA,
                   temp_dew_nearest = NA)
      )
  }

  # Compute twet and rh
  modeled_met <- modeled_met %>%
    dplyr::mutate(
      temp_dew_idw_lapse_var =
        dplyr::case_when(temp_dew_idw_lapse_var > temp_air_idw_lapse_var ~temp_air_idw_lapse_var,
                         TRUE ~ temp_dew_idw_lapse_var),
      rh = humidity::relhum(temp_air_idw_lapse_var, temp_dew_idw_lapse_var)
      ) %>%
    dplyr::mutate(
      rh = dplyr::case_when(rh > 100 ~ 100,
                            TRUE ~ rh)
      ) %>%
    dplyr::mutate(
      temp_wet = humidity::wetbulb(temp_air_idw_lapse_var, rh)
    )

  # Return the data frame
  return(modeled_met)

}
