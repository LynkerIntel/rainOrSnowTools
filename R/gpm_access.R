`%>%` <- dplyr::`%>%`

#' Download GPM IMERG data
#'
#' @param datetime_utc Observation time
#' @param lon Longitude in decimal degrees
#' @param lat Latitude in decimal degrees
#' @param obs Dataframe of observations if one obs is not given
#'
#' @return a dataframe of GPM data for each observation
#' @export
#'
#' @examples
#' EDusername = XXX
#' EDpassword = XXX
#' datetime = as.POSIXct("2023-01-01 16:00:00", tz = "UTC")
#' lon = -105
#' lat = 40
#' gpm <- get_imerg(datetime_utc = datetime,
#'                  lon = lon,
#'                  lat = lat,
#'                  obs = test)
get_imerg <- function(datetime_utc,
                      lon,
                      lat,
                      obs){

    # Package load
    # Is this the right way to do it?
    pacman::p_load(hydrofabric, lubridate, plyr)

    # # Account info for Earthdata : https://urs.earthdata.nasa.gov/
    # climateR::writeNetrc(login = username, password = password, overwrite = TRUE)
    # climateR::writeDodsrc(overwrite = TRUE)

    ## ASSIGN GPM variable
    var = 'probabilityLiquidPrecipitation'

    # If there is no data frame with obs provided, then need lat/lon pts
    if (!missing(obs))
      tmp.data = obs
      else tmp.data = data.frame("longitude" = lon,
                                 "latitude" = lat)

    # Observation data is converted into shapefile format
    data = sf::st_as_sf(tmp.data, coords = c("longitude", "latitude"), crs = 4326)

    # URL structure
    base         = 'https://gpm1.gesdisc.eosdis.nasa.gov/opendap/hyrax/GPM_L3/GPM_3IMERGHHL.06'
    product      = '3B-HHR-L.MS.MRG.3IMERG'
    url_pattern  = '{base}/{year}/{julian}/{product}.{year}{month}{day}-S{hour}{minTime}00-E{hour}{nasa_time_minute}{nasa_time_second}.{min}.V06B.HDF5'
    url_pattern2 = '{base}/{year}/{julian}/{product}.{year}{month}{day}-S{hour}{minTime}00-E{hour}{nasa_time_minute}{nasa_time_second}.{min}.V06C.HDF5'

    l = list()

    ## Build URLs
    data = data %>%
      dplyr::mutate(dateTime = as.POSIXct(utc_datetime)) %>%
      dplyr::mutate(
        julian  = format(dateTime, "%j"),
        year    = format(dateTime, "%Y"),
        month   = format(dateTime, "%m"),
        day     = format(dateTime, "%d"),
        hour    = sprintf("%02s", format(dateTime, "%H")),
        minTime = sprintf("%02s", plyr::round_any(as.numeric(
          format(dateTime, "%M")
        ), 30, f = floor)),
        origin_time  = as.POSIXct(paste0(format(
          dateTime, "%Y-%m-%d"
        ), "00:00"), tz = "UTC"),
        rounded_time = as.POSIXct(paste0(
          format(dateTime, "%Y-%m-%d"), hour, ":", minTime
        ), tz = "UTC"),
        nasa_time = rounded_time + (29 * 60) + 59,
        nasa_time_minute = format(nasa_time, "%M"),
        nasa_time_second = format(nasa_time, "%S"),
        min = sprintf("%04s", difftime(rounded_time, origin_time,  units = 'min')),
        url = glue::glue(url_pattern),
        url2 = glue::glue(url_pattern2)
      ) %>%
      # !! ADD ANYTHING YOU WANT TO KEEP HERE !!
      dplyr::select(dplyr::any_of(c('utc_datetime', 'phase', 'url', 'url2')))


    ## Get Data

    for (x in 1:nrow(data)) {
      l[[x]] = tryCatch({
        dap(
          URL = data$url[x],
          varname = var,
          AOI = data[x, ],
          verbose = FALSE
        )
      }, error = function(e) {
        dap(
          URL = data$url2[x],
          varname = var,
          AOI = data[x, ],
          verbose = FALSE
        )
      })
    }

    gpm_obs = cbind(data, bind_rows(l))

    # Return the dataframe
    gpm_obs = gpm_obs %>%
      sf::st_drop_geometry() %>% # drop geometry column to make it dataframe
      dplyr::select(c('utc_datetime', 'probabilityLiquidPrecipitation')) %>%
      left_join(., tmp.data, by = 'utc_datetime')

    gpm_obs

  }



