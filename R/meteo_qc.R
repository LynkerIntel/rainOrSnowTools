# Functions for quality controlling meteorological data

`%>%` <- dplyr::`%>%`

qc_meteo <- function(df,
                     tair_limit_min=-30, tair_limit_max=45,
                     twet_limit_min=-40, twet_limit_max=45,
                     tdew_limit_min=-40, tdew_limit_max=45,
                     rh_limit_min=10,    rh_limit_max=100,
                     sd_thresh=3){
  # Identify the column names
  cols <- colnames(df)

  # Check for column names
  if(("temp_air" %in% cols | "temp_wet" %in% cols | "temp_dew" %in% cols |
      "rh" %in% cols) == FALSE) {
    warning("missing a valid column (temp_air, temp_wet, temp_dew, or rh)")
  }

  # Call the qc functions if the column is present
  if("temp_air" %in% cols){
    var_qc = qc_var(df$temp_air,
                    limit_min = tair_limit_min, limit_max = tair_limit_max,
                    sd_threshold = sd_thresh)
    df$temp_air = var_qc
  }
  if("temp_wet" %in% cols){
    var_qc = qc_var(df$temp_wet,
                    limit_min = twet_limit_min, limit_max = twet_limit_max,
           sd_threshold = sd_thresh)
    df$temp_wet = var_qc
  }
  if("temp_dew" %in% cols){
    var_qc = qc_var(df$temp_dew,
                    limit_min = tdew_limit_min, limit_max = tdew_limit_max,
           sd_threshold = sd_thresh)
    df$temp_dew = var_qc
  }
  if("rh" %in% cols){
    var_qc = qc_var(df$rh,
                    limit_min = rh_limit_min, limit_max = rh_limit_max,
           sd_threshold = sd_thresh)
    df$rh = var_qc
  }

  # Return the data frame
  df

}

qc_var <- function(var, limit_min, limit_max, sd_threshold){

  # Filter by limits
  var_qc <- ifelse(var < limit_min | var > limit_max,
                   NA,
                   var)

  # Filter by standard deviation
  var_mean = mean(var_qc, na.rm = T)
  var_sd = sd(var_qc, na.rm = T)
  var_qc <- ifelse(var_qc < var_mean - (sd_threshold * var_sd) |
                     var_qc > var_mean + (sd_threshold * var_sd),
                   NA,
                   var_qc)

  # Return var_qc
  var_qc
}
