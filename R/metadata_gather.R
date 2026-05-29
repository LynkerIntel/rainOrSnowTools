# Declare global variables to pass R-CMD-check
utils::globalVariables(c("US_L3NAME"))

#' Function to gather metadata from a list of stations
#'
#' @param stations Vector of station ids (HADS, LCD, WCC) or the station data itself for MADIS
#' @param network The station's network ("HADS", "LCD", "WCC", "MADIS")
#' @return A dataframe of filtered station metadata
#' @importFrom dplyr filter select bind_rows
#' @export
gather_meta <- function(stations, network) {

  # Filter the metadata to only those in the station list

  metdata_list <- list()

  # Access HADS data
  if (network == "HADS") {
    # Error handling when it comes to no stations reported in the timezones
    tryCatch({
      tmp_stations <- stations %>%
        dplyr::select(name = station_name,
                      id = stid,
                      lat,
                      lon,
                      elev,
                      timezone_lst,
                      provider = iem_network) %>%
        dplyr::mutate(network = "hads")

      metdata_list[["HADS"]] <- tmp_stations

    }, error = function(e) {})
  }

  # Access LCD data
  if (network == "LCD") {
    # Error handling when it comes to no stations reported in the timezones
    tryCatch({
      tmp_stations <- stations %>%
        dplyr::select(
          name = station_name,
          id = stid,
          lat,
          lon,
          elev = elev_m,
          timezone_lst
        ) %>%
        dplyr::mutate(network = "lcd",
                      provider = NA)

      metdata_list[["LCD"]] <- tmp_stations

    }, error = function(e) {})
  }

  # Access WCC data
  if(network == "WCC"){
    # Error handling when it comes to no stations reported in the timezones
    tryCatch({
      tmp_stations <- stations %>%
        dplyr::select(name = site_name,
                      id = station.id,
                      lat, lon,
                      elev = elev_m,
                      timezone_lst,
                      network) %>%
        dplyr::mutate(id = as.character(id),
                      provider = NA)

      metdata_list[["WCC"]] <- tmp_stations

    }, error = function(e){})
  }

  # Access MADIS data
  if(network == "MADIS"){
    tryCatch({
      tmp_stations <- stations %>%
        dplyr::select(id = STAID,
                      lat = LAT,
                      lon = LON,
                      elev = ELEV,
                      provider = PVDR) %>%
        dplyr::mutate(network = "madis",
                      name = NA,
                      timezone_lst = NA
                      )

      metdata_list[["MADIS"]] <- tmp_stations

    }, error = function(e){})
  }

  metdata_all <- dplyr::bind_rows(metdata_list)

  # if no stations are found, return an empty data frame with column names
  if (nrow(metdata_all) < 1) {
    # provide empty data frame with column names
    metdata_all <- data.frame(
      name = character(0),
      id = character(0),
      lat = numeric(0),
      lon = numeric(0),
      elev = numeric(0),
      timezone_lst = character(0),
      network = character(0),
      provider = character(0)
    )

  }

  # Return the met_all data frame
  return(metdata_all)

}

