# Function to pare down meteorological data to those closest in time

# Get the pipe
`%>%` <- dplyr::`%>%` # add dplyr pipe


select_meteo <- function(df, datetime_obs){

  # Identify the column names
  cols <- colnames(df)

  # Check for column names in df
  if(("temp_air" %in% cols | "temp_wet" %in% cols | "temp_dew" %in% cols |
      "rh" %in% cols) == FALSE) {
    stop("missing a valid column (temp_air, temp_wet, temp_dew, or rh")
  }

  # Make the data longer
  # filter the na values
  # add a time gap for each station measurement to the observation
  # calculate and filter to the min time gap for each station and var
  # get the mean value for each met data point
  # pivot back to wider data frame
  df <- df %>%
    tidyr::pivot_longer(!id:datetime) %>%
    dplyr::filter(!is.na(value)) %>%
    dplyr::mutate(time_gap = abs(datetime - datetime_obs)) %>%
    dplyr::group_by(id, name) %>%
    dplyr::mutate(time_gap_min = min(time_gap)) %>%
    dplyr::filter(time_gap == min(time_gap)) %>%
    dplyr::group_by(id, name) %>%
    dplyr::summarise(value = mean(value),
                     time_gap = mean(time_gap)) %>%
    tidyr::pivot_wider(names_from = name, values_from = value)

  # Return the data frame
  df
}
