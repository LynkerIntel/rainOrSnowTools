# Functions for processing raw Mountain Rain or Snow citizen science observations

#' Get the time zone for an observation with a latitude and longitude
#'
#' @param lon_obs Longitude of observation in decimal degrees (°)
#' @param lat_obs Latitude of observation in decimal degrees (°)
#'
#' @return The local standard time zone in the format "Etc/GMT+X"
#' Where X is the offset in hours from GMT
#' @importFrom lutz tz_lookup_coords
#' @importFrom dplyr left_join `%>%`
#'
#' @examples
#' \dontrun{
#' lon = -120
#' lat = 40
#' get_tz(lon, lat)
#' }
get_tz <- function(lon_obs, lat_obs){
  # Make the timezone table
  tz_table <- make_tz_table()

  # Get the standard timezone of the obs
  tmp_tz <- data.frame(
    tz_name = lutz::tz_lookup_coords(lat = lat_obs,
                                   lon = lon_obs,
                                   method = "accurate"))

  # Join the tz_table
  tmp_tz = dplyr::left_join(tmp_tz, tz_table,
                            by = "tz_name")

  # Output the timezone
  tmp_tz$timezone_lst
}

#' Build a table of timezones and offsets when called from get_tz
#'
#' @return A table of PST, MST, CST, and EST timezones
#' @importFrom lutz tz_list
#' @importFrom dplyr filter mutate `%>%`
#' @export
make_tz_table <- function(){

  # TODO: only support 4 time zones currently
  # Add support for more

  # Build out table for Pacific, Mountain, Central, and Eastern Standard Times
  lutz::tz_list() %>%
    dplyr::filter(zone %in% c("PST", "MST", "CST", "EST")) %>%
    dplyr::mutate(timezone_lst = paste0("Etc/GMT+", (utc_offset_h * (-1))))
}

#' Get elevation based on lat/lon
#'
#' @param lon_obs Longitude of observation in decimal degrees (°)
#' @param lat_obs Latitude of observation in decimal degrees (°)
#'
#' @return Elevation based on location
#' @importFrom lutz tz_list
#' @importFrom terra rast extract
#' @export
get_elev <- function(lon_obs, lat_obs){
  locs = cbind(lon_obs, lat_obs)
  r = terra::rast("/vsicurl/https://prd-tnm.s3.amazonaws.com/StagedProducts/Elevation/13/TIFF/USGS_Seamless_DEM_13.vrt")
  terra::extract(r, locs) %>% as.numeric()
}

#' Geolocate location to assign ecoregion 3 association
#'
#' @param lon_obs Longitude of observation in decimal degrees (°)
#' @param lat_obs Latitude of observation in decimal degrees (°)
#'
#' @return Ecoregion level 3
#' @importFrom sf st_as_sf sf_use_s2 st_intersection st_drop_geometry
#' @importFrom dplyr select `%>%`
#' @export
#' @examples
#' \dontrun{
#' lon = -105
#' lat = 40
#' ecoregion3 <- get_eco_level3(lon, lat)
#' }
get_eco_level3 <- function(lon_obs, lat_obs){

  locs = sf::st_as_sf(data.frame(lon_obs, lat_obs),
                          coords = c("lon_obs", "lat_obs"), crs = 4326)

 suppressMessages(suppressWarnings({

   sf::sf_use_s2(FALSE)

   sf::st_intersection(locs, ecoregions_states) %>%
     dplyr::select("Ecoregion" = US_L3NAME) %>%
     sf::st_drop_geometry() %>%
     as.character()

 }))

}

#' Geolocate location to assign ecoregion 4 association
#'
#' @param lon_obs Longitude of observation in decimal degrees (°)
#' @param lat_obs Latitude of observation in decimal degrees (°)
#'
#' @return Ecoregion level 4
#' @importFrom sf st_as_sf sf_use_s2 st_intersection st_drop_geometry
#' @importFrom dplyr select `%>%`
#' @export
#' @examples
#' \dontrun{
#' lon = -105
#' lat = 40
#' ecoregion4 <- get_eco_level4(lon, lat)
#' }
get_eco_level4 <- function(lon_obs, lat_obs) {

  locs = sf::st_as_sf(data.frame(lon_obs, lat_obs),
                      coords = c("lon_obs", "lat_obs"), crs = 4326)

  suppressMessages(suppressWarnings({

    sf::sf_use_s2(FALSE)

    sf::st_intersection(locs, ecoregions_states) %>%
      dplyr::select("Ecoregion" = US_L4NAME) %>%
      sf::st_drop_geometry() %>%
      as.character()

  }))

}

#' Geolocate location to assign state association
#'
#' @param lon_obs Longitude of observation in decimal degrees (°)
#' @param lat_obs Latitude of observation in decimal degrees (°)
#'
#' @return State
#' @importFrom sf st_as_sf sf_use_s2 st_intersection st_drop_geometry
#' @importFrom dplyr select `%>%`
#' @export
#' @examples
#' \dontrun{
#' lon = -105
#' lat = 40
#' state <- get_state(lon, lat)
#' }
get_state <- function(lon_obs, lat_obs){

  locs = sf::st_as_sf(data.frame(lon_obs, lat_obs),
                      coords = c("lon_obs", "lat_obs"), crs = 4326)

  suppressMessages(suppressWarnings({

    sf::sf_use_s2(FALSE)

    sf::st_intersection(locs, ecoregions_states) %>%
      dplyr::select("State" = STATE_NAME) %>%
      sf::st_drop_geometry() %>%
      as.character()


  }))

}

#' Download GPM IMERG data
#'
#' @param datetime_utc observation time
#' @param lon_obs longitude of observation in decimal degrees (°)
#' @param lat_obs latitude of observation in decimal degrees (°)
#' @param version IMERG versions: 6 = late run v6 and 7 = final run v7
#'
#' @return a dataframe of GPM data for each observation
#' @importFrom sf st_as_sf st_drop_geometry
#' @importFrom dplyr mutate any_of select bind_rows `%>%`
#' @importFrom plyr round_any
#' @importFrom pacman p_load
#' @importFrom glue glue
#' @importFrom climateR dap
#' @importFrom xml2 read_xml xml_find_all xml_attrs
#' @export
#' @examples
#' \dontrun{
#' datetime_utc = as.POSIXct("2023-01-01 16:00:00", tz = "UTC")
#' lon = -105
#' lat = 40
#' gpm <- get_imerg(datetime_utc, lon_obs = lon, lat_obs = lat, version = 6)
#' }
get_imerg <- function(datetime_utc,
                      lon_obs,
                      lat_obs,
                      version = 6) {

  # Assign GPM variable
  var = 'probabilityLiquidPrecipitation'

  # Observation data is converted into shapefile format
  data = sf::st_as_sf(
    data.frame(datetime_utc, lon_obs, lat_obs),
    coords = c("lon_obs", "lat_obs"),
    crs  = 4326
  )

  tryCatch({
    if (version == 6) {
      # URL structure
      base = 'https://gpm1.gesdisc.eosdis.nasa.gov/opendap/hyrax/GPM_L3/GPM_3IMERGHHL.06'
      product = '3B-HHR-L.MS.MRG.3IMERG'
      url_trim = '{base}/{year}/{julian}/'
      product_pattern = '{product}.{year}{month}{day}-S{hour}{minTime}00-E{hour}{nasa_time_minute}{nasa_time_second}.{min}.'

      ## Build URLs
      data = data %>%
        dplyr::mutate(dateTime = as.POSIXct(datetime_utc)) %>%
        dplyr::mutate(
          julian  = format(dateTime, "%j"),
          year    = format(dateTime, "%Y"),
          month   = format(dateTime, "%m"),
          day     = format(dateTime, "%d"),
          hour    = sprintf("%02s", format(dateTime, "%H")),
          minTime = sprintf("%02s", plyr::round_any(as.numeric(
            format(dateTime, "%M")
          ), 30, f = floor)),
          origin_time  = as.POSIXct(paste0(
            format(dateTime, "%Y-%m-%d"), "00:00"
          ), tz = "UTC"),
          rounded_time = as.POSIXct(paste0(
            format(dateTime, "%Y-%m-%d"), hour, ":", minTime
          ), tz = "UTC"),
          nasa_time = rounded_time + (29 * 60) + 59,
          nasa_time_minute = format(nasa_time, "%M"),
          nasa_time_second = format(nasa_time, "%S"),
          min = sprintf(
            "%04s",
            difftime(rounded_time, origin_time,  units = 'min')
          ),
          url_0 = glue::glue(url_trim),
          product_info = glue::glue(product_pattern)
        ) %>%
        dplyr::select(dplyr::any_of(c(
          'datetime_utc', 'url_0', 'product_info'
        )))

      # Visit the XML page to get the right V06[X] values (e.g. D,E,...)
      url_base <- paste0(data$url_0, "catalog.xml")
      prod <- data$product_info
      xml <- xml2::read_xml(url_base) %>%
        xml2::xml_find_all(glue::glue('///thredds:dataset[contains(@name, "{prod}")]'))
      prod_name <- xml2::xml_attrs(xml[[1]])[["name"]]

      # Create URL
      final_url = paste0(data$url_0, prod_name)

    }

    if (version == 7) {
      # URL structure
      base = 'https://gpm1.gesdisc.eosdis.nasa.gov/opendap/GPM_L3/GPM_3IMERGHH.07'
      product = '3B-HHR.MS.MRG.3IMERG'
      url_trim = '{base}/{year}/{julian}/'
      product_pattern = '{product}.{year}{month}{day}-S{hour}{minTime}00-E{hour}{nasa_time_minute}{nasa_time_second}.{min}.'

      ## Build URLs
      data = data %>%
        dplyr::mutate(dateTime = as.POSIXct(datetime_utc)) %>%
        dplyr::mutate(
          julian  = format(dateTime, "%j"),
          year    = format(dateTime, "%Y"),
          month   = format(dateTime, "%m"),
          day     = format(dateTime, "%d"),
          hour    = sprintf("%02s", format(dateTime, "%H")),
          minTime = sprintf("%02s", plyr::round_any(as.numeric(
            format(dateTime, "%M")
          ), 30, f = floor)),
          origin_time  = as.POSIXct(paste0(
            format(dateTime, "%Y-%m-%d"), "00:00"
          ), tz = "UTC"),
          rounded_time = as.POSIXct(paste0(
            format(dateTime, "%Y-%m-%d"), hour, ":", minTime
          ), tz = "UTC"),
          nasa_time = rounded_time + (29 * 60) + 59,
          nasa_time_minute = format(nasa_time, "%M"),
          nasa_time_second = format(nasa_time, "%S"),
          min = sprintf(
            "%04s",
            difftime(rounded_time, origin_time,  units = 'min')
          ),
          url_0 = glue::glue(url_trim),
          product_info = glue::glue(product_pattern)
        ) %>%
        dplyr::select(dplyr::any_of(c(
          'datetime_utc', 'url_0', 'product_info'
        )))

      # Visit the XML page to get the right V07[X] values (e.g. A,B,...)
      url_base <- paste0(data$url_0, "catalog.xml")
      prod <- data$product_info
      xml <- xml2::read_xml(url_base) %>%
        xml2::xml_find_all(glue::glue('///thredds:dataset[contains(@name, "{prod}")]'))
      prod_name <- xml2::xml_attrs(xml[[1]])[["name"]]

      # Create URL
      final_url = paste0(data$url_0, prod_name)
    }

    ## Get Data
    gpm_obs =
      climateR::dap(
        URL = final_url,
        varname = var,
        AOI = data,
        verbose = FALSE
      )

    gpm_obs = gpm_obs %>%
      sf::st_drop_geometry() %>% # Drop geometry column to make it dataframe
      dplyr::select(dplyr::all_of((var)))

    return(gpm_obs)

  }, error = function(er) {
    if (version == 7) {
      message("Final Run v7 data likely unavailable for datetime.")
    } else{
      message("Original error message:")
      message(conditionMessage(er))
    }

    # If error, return NA as value
    NA

  })
}
