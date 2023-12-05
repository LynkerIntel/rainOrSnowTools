# # Function to pare down meteorological data to those closest in time

# Declare global variables to pass R-CMD-check
utils::globalVariables(
  c("id", "datetime", "value", "name", "time_gap", ".", "REPORT_TYPE", "STATION")
)

# # Get the pipe
# `%>%` <- dplyr::`%>%` # add dplyr pipe
#

#' Function to pare down meteorological data to those closest in time
#'
#' @param df data.frame
#' @param datetime_obs Date or character
#'
#' @return data.frame
#' @importFrom dplyr filter mutate group_by summarise `%>%`
#' @importFrom tidyr pivot_longer pivot_wider
select_meteo <- function(df, datetime_obs){

  # Identify the column names
  cols <- colnames(df)

  # Check for column names in df
  if(("temp_air" %in% cols | "temp_wet" %in% cols | "temp_dew" %in% cols |
      "rh" %in% cols) == FALSE) {
    warning("missing a valid column (temp_air, temp_wet, temp_dew, or rh")
  }

  # Additional function to assure all columns are included in final DF
  add_cols <- function(df, cols) {
    add <- cols[!cols %in% names(df)]
    if(length(add) != 0) df[add] <- NA
    return(df)
  }

  # Define columns that should be included
  all_cols <- c("temp_air", "temp_wet", "temp_dew", "rh")

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
    tidyr::pivot_wider(names_from = name, values_from = value) %>%
    add_cols(., all_cols)

  # Return the data frame
  df
}
