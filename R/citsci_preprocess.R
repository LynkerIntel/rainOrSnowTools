# Functions for processing raw Mountain Rain or Snow citizen science observations

# Declare global variables to pass R-CMD-check
utils::globalVariables(
  c("US_L3NAME", "US_L4NAME", "dateTime", "minTime", "rounded_time", "nasa_time", "origin_time",
    "STATE_NAME", "zone", "utc_offset_h", "probabilityLiquidPrecipitation", "datetime_utc")
)

#' Get the time zone for an observation with a latitude and longitude
#'
#' @param lon_obs longitude of observation in decimal degrees (°)
#' @param lat_obs latitude of observation in decimal degrees (°)
#'
#' @return the local standard time zone in the format "Etc/GMT+X"
#' where X is the offset in hours from GMT
#' @importFrom lutz tz_lookup_coords
#' @importFrom dplyr left_join `%>%`
#'
#' @examples
#' \dontrun{
#' lon = -120
#' lat = 40
#' get_tz(lon, lat)
#' }
get_tz <- function(lon_obs, lat_obs) {

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
  return(tmp_tz$timezone_lst)

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
  tz_table <-
    lutz::tz_list() %>%
    dplyr::filter(zone %in% c("PST", "MST", "CST", "EST")) %>%
    dplyr::mutate(timezone_lst = paste0("Etc/GMT+", (utc_offset_h * -1)))

  # check if table is valid
  if (nrow(tz_table) == 0) {
    stop("No valid time zones found in tz_list().")
  }

  return(tz_table)

}

#' Get elevation based on lat/lon
#' @param lon_obs numeric, Longitude in decimal degrees. Default is NULL.
#' @param lat_obs numeric, Latitude in decimal degrees. Default is NULL.
#' @return Elevation based on location
#' @importFrom lutz tz_list
#' @importFrom terra rast extract
#' @export
get_elev <- function(lon_obs, lat_obs){
  locs = cbind(lon_obs, lat_obs)
  r = terra::rast("/vsicurl/https://prd-tnm.s3.amazonaws.com/StagedProducts/Elevation/13/TIFF/USGS_Seamless_DEM_13.vrt")

  return(
    as.numeric(
      terra::extract(r, locs)
      )
    )
}

#' Geolocate location to assign ecoregion 3 association
#'
#' @return Ecoregion level 3
#' @param lon_obs numeric, Longitude in decimal degrees. Default is NULL.
#' @param lat_obs numeric, Latitude in decimal degrees. Default is NULL.
#' @importFrom sf st_as_sf sf_use_s2 st_intersection st_drop_geometry
#' @importFrom dplyr select `%>%`
#' @examples
#' \dontrun{
#' lon = -105
#' lat = 40
#' ecoregion3 <- get_eco_level3(lon, lat)
#' }
get_eco_level3 <- function(lon_obs, lat_obs){

  # get ecoregions_states data from R/sysdata.rda
  ecoregions_states <- get0("ecoregions_states", envir = asNamespace("rainOrSnowTools"))

  # sf dataframe of locations
  locs = sf::st_as_sf(
              data.frame(lon_obs, lat_obs),
              coords = c("lon_obs", "lat_obs"),
              crs    = 4326
              )

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
#' @return Ecoregion level 4
#' @param lon_obs numeric, Longitude in decimal degrees. Default is NULL.
#' @param lat_obs numeric, Latitude in decimal degrees. Default is NULL.
#' @importFrom sf st_as_sf sf_use_s2 st_intersection st_drop_geometry
#' @importFrom dplyr select `%>%`
#' @examples
#' \dontrun{
#' lon = -105
#' lat = 40
#' ecoregion4 <- get_eco_level4(lon, lat)
#' }
get_eco_level4 <- function(lon_obs, lat_obs) {

  # get ecoregions_states data from R/sysdata.rda
  ecoregions_states <- get0("ecoregions_states", envir = asNamespace("rainOrSnowTools"))

  # sf dataframe of locations
  locs = sf::st_as_sf(
              data.frame(lon_obs, lat_obs),
              coords = c("lon_obs", "lat_obs"),
              crs = 4326
              )

  suppressMessages(suppressWarnings({

    sf::sf_use_s2(FALSE)

    sf::st_intersection(locs, ecoregions_states) %>%
    # sf::st_intersection(locs, rainOrSnowTools::ecoregions_states) %>%
      dplyr::select("Ecoregion" = US_L4NAME) %>%
      sf::st_drop_geometry() %>%
      as.character()

  }))

}

#' Geolocate location to assign state association
#' @param lon_obs numeric, Longitude in decimal degrees. Default is NULL.
#' @param lat_obs numeric, Latitude in decimal degrees. Default is NULL.
#' @return State
#' @importFrom sf st_as_sf sf_use_s2 st_intersection st_drop_geometry
#' @importFrom dplyr select `%>%`
#' @examples
#' \dontrun{
#' lon = -105
#' lat = 40
#' state <- get_state(lon, lat)
#' }
get_state <- function(lon_obs, lat_obs){

  # get ecoregions_states data from R/sysdata.rda
  ecoregions_states <- get0("ecoregions_states", envir = asNamespace("rainOrSnowTools"))

  # sf dataframe of locations
  locs = sf::st_as_sf(
              data.frame(lon_obs, lat_obs),
              coords = c("lon_obs", "lat_obs"),
              crs = 4326
              )

  suppressMessages(suppressWarnings({

    sf::sf_use_s2(FALSE)

    sf::st_intersection(locs, ecoregions_states) %>%
      dplyr::select("State" = STATE_NAME) %>%
      sf::st_drop_geometry() %>%
      as.character()


  }))

}

#' Get the resource URLs from NASA GPM XML Catalog
#' This function reads the catalog.xml file from the hyrax GPM IMERG catalog.xml URL and
#' extracts the "dap" service files, and returns them as a character vector
#' @param url character string URL to the catalog.xml file
#' @param verbose logical, whether to print out messages or not
#' @importFrom xml2 read_xml xml_find_all xml_attrs
#' @importFrom glue glue
#' @family imerg
#' @return vector of URLs for daily GPM IMERG resources
get_final_urls <- function(url, verbose = FALSE) {

  # read the catalog.xml file from the url
  xml_data <- xml2::read_xml(url)

  if(verbose) {
    message("Length of xml_data: ", length(xml_data))
  }

  # get all the thredds dataset xpaths
  dap_xmls <-
    xml_data %>%
    xml2::xml_find_all(glue::glue('////thredds:dataset'))

  if(verbose) {
    message("Number of thredds:dataset nodes: ", length(dap_xmls))
  }

  # extract only the "dap" service files
  dap_xmls <-
    dap_xmls %>%
    xml2::xml_find_all(glue::glue('///thredds:access[contains(@serviceName, "dap")]'))

  if(verbose) {
    message("Number of thredds:dataset DAP nodes: ", length(dap_xmls))
    message("Extracting attributes from dap_xmls...")
  }

  # extract the attributes from all of the dap_xmls
  dap_attrs <- xml2::xml_attrs(dap_xmls)

  if(verbose) {
    message("Extracting URL paths from attributes...")
  }

  # construct final URLs vector
  dap_paths <- sapply(dap_attrs, function(x) {
    paste0("https://gpm1.gesdisc.eosdis.nasa.gov/opendap/hyrax", x[["urlPath"]])
  })

  return(dap_paths)

}


#' Construct the product name of GPM IMERG data for a given date in YYYY-MM-DDTHH:MM:SS.000Z format UTC time
#'
#' @param date_of_interest character string date in YYYY-MM-DDTHH:MM:SS.000Z format UTC time (e.g. "2024-01-26T17:16:43.000Z")
#' @param product_version character string of the GPM IMERG product version (e.g. "GPM_3IMERGHHL.06").'
#'      Available versions are "GPM_3IMERGHHL.06", "GPM_3IMERGHHE.06", "GPM_3IMERGHHL.07", and "GPM_3IMERGHH.07". Defaults to IMERG Late Run.
#' @importFrom glue glue
#' @importFrom plyr round_any
#' @family imerg
#' @return character GPM IMERG product name for the given date
construct_gpm_product <- function(date_of_interest, product_version = NULL) {

  # for testing: date_of_interest = "2024-06-02T17:16:43.000Z"

  # Convert date_of_interest to POSIXct
  dateTime <- as.POSIXct(date_of_interest, format = "%Y-%m-%dT%H:%M:%OS",  tz = "UTC")

  # Since 2024-06-01, IMERG v7 is the dominant HHL data feed
  # Grab the right IMERG version based on date
  # IF the user defines the wrong thing, make the default for them
  product_version <- get_valid_product_version_for_date(product_version, dateTime)

  versions <- rainOrSnowTools::product_versions

  # throw an error if the product_version is not in the versions list
  if(!product_version %in% names(versions)) {
    stop("Invalid 'product_version' argument, must be one of:\n > ", paste(paste0("'", names(versions), "'"), collapse = "\n > "))
  }

  # Define URL structure

  base_and_product <- versions[[product_version]]
  base    <- base_and_product[1]
  product <- base_and_product[2]

  url_trim <- "{base}/{year}/{julian}/"
  product_pattern <- "{product}.{year}{month}{day}-S{hour}{minTime}00-E{hour}{nasa_time_minute}{nasa_time_second}.{minutes_diff}."

  # Extract necessary date components
  julian  <- format(dateTime, "%j")
  year    <- format(dateTime, "%Y")
  month   <- format(dateTime, "%m")
  day     <- format(dateTime, "%d")
  hour    <- sprintf("%02s", format(dateTime, "%H"))
  minTime <- sprintf("%02d", plyr::round_any(as.numeric(format(dateTime, "%M")), 30, f = floor))

  # Calculate additional time components
  origin_time <- as.POSIXct(paste0(format(dateTime, "%Y-%m-%d"), "00:00"), tz = "UTC")
  rounded_time <- as.POSIXct(paste0(format(dateTime, "%Y-%m-%d"), hour, ":", minTime), tz = "UTC")

  # Calculate the NASA time components
  nasa_time <- rounded_time + (29 * 60) + 59
  nasa_time_minute <- format(nasa_time, "%M")
  nasa_time_second <- format(nasa_time, "%S")

  # Calculate the time difference
  minutes_diff <- sprintf("%04d", difftime(rounded_time, origin_time,  units = 'min'))

  # Generate base URL and product name
  url_0 <- glue::glue(url_trim)
  product_info <- as.character(glue::glue(product_pattern))

  # Return the constructed product name
  return(product_info)
}

#' Construct the base URL for GPM IMERG data for a given date timestamp
#'
#' @param date_of_interest character string date in YYYY-MM-DDTHH:MM:SS.000Z format UTC time (e.g. "2024-01-26T17:16:43.000Z")
##' @param product_version character string of the GPM IMERG product version (e.g. "GPM_3IMERGHHL.06").'
#'      Available versions are "GPM_3IMERGHHL.06", "GPM_3IMERGHHE.06", "GPM_3IMERGHHL.07", and "GPM_3IMERGHH.07". Defaults to IMERG Late Run.
#' @importFrom glue glue
#' @family imerg
#' @return character GPM IMERG base URL for the given date
construct_gpm_base_url <- function(date_of_interest, product_version = NULL) {

  ##############################
  # for testing:
  # date_of_interest = datetime_utc
  # date_of_interest = "2024-01-25T01:45:59.000Z"
  # date_of_interest = "2024-01-26T17:16:43.000Z"
  # product_version = product_version
  # product_version = "GPM_3IMERGHHE.06"
  ##############################

  # Convert date_of_interest to POSIXct (YYYY-MM-DDTHH:MM:SS.000Z format UTC time)
  dateTime <- as.POSIXct(date_of_interest, format = "%Y-%m-%dT%H:%M:%OS",  tz = "UTC")

  # Since 2024-06-01, IMERG v7 is the dominant HHL data feed
  # Grab the right IMERG version based on date
  # IF the user defines the wrong thing, make the default for them
  product_version <- get_valid_product_version_for_date(product_version, dateTime)

  # Define URL structure

  # list of available GPM IMERG product versions
  versions <- rainOrSnowTools::product_versions

  # throw an error if the product_version is not in the versions list
  if(!product_version %in% names(versions)) {
    stop("Invalid 'product_version' argument, must be one of:\n > ", paste(paste0("'", names(versions), "'"), collapse = "\n > "))
  }

  base     <- versions[[product_version]]

  # character to insert values into via glue::glue()
  url_trim <- "{base}/{year}/{julian}/"

  # Extract necessary date components
  julian  <- format(dateTime, "%j")
  year    <- format(dateTime, "%Y")

  # Generate base URL and product name
  base_url <- as.character(glue::glue(url_trim))

  # Return the GPM base_url
  return(base_url)

}

#' Get the closest URL to the "match_string" string
#' Uses the Levenshtein distance to find the closest URL to the "match_string", match string is the "product name" string determined by the construct_gpm_product() function
#' @param urls character vector of URLs
#' @param match_string string to partial match with
#' @importFrom utils adist
#' @family imerg
#' @return character of the closest URL to the "match_string"
get_closest_url <- function(urls, match_string) {
  # Calculate Levenshtein distances between the "match_string" and "urls"
  string_distances <- sapply(urls, function(url) {
    utils::adist(match_string, url)
  })

  # Get the index of the minimum distance
  min_index <- which.min(string_distances)

  # Return the closest URL
  return(urls[min_index])
}



#' Get the most optimal (or correct) product version for a given date
#'
#' @param product_version character product version
#' @param dateTime date character
#'
#' @return character
get_valid_product_version_for_date <- function(product_version, dateTime) {

  # Since 2024-06-01, IMERG v7 is the dominant HHL data feed = default to v7
  # IF the user defines the wrong version, make the default for them
  if(missing(product_version)) {
    product_version <- "GPM_3IMERGHHL.07"
    }
  else if (product_version == "GPM_3IMERGHHL.06") {
    message("IMERGv6 is no longer supported 2024-06-01, defaulting to using IMERGv7")
    product_version <- "GPM_3IMERGHHL.07"
    }
  else {
    product_version <- product_version
  }

  return(product_version)

}


#' Get GPM IMERG PLP data for a specified lat/lon and datetime
#' @param datetime_utc Observation time in UTC format YYYY-MM-DD HH:MM:SS. Default is NULL.
#' @param lon_obs numeric, Longitude in decimal degrees. Default is NULL.
#' @param lat_obs numeric, Latitude in decimal degrees. Default is NULL.
#' @param product_version character string of the GPM IMERG product version (e.g. "GPM_3IMERGHHL.06").'
#'      Available versions are "GPM_3IMERGHHL.06", "GPM_3IMERGHHE.06", "GPM_3IMERGHHL.07", and "GPM_3IMERGHH.07". Defaults to IMERG Late Run.
#' @param verbose logical, whether to print messages or not. Default is FALSE
#' @return a dataframe of GPM data for each observation
#' @importFrom sf st_as_sf st_drop_geometry
#' @importFrom dplyr mutate any_of all_of select bind_rows select `%>%`
#' @importFrom plyr round_any
#' @importFrom pacman p_load
#' @importFrom glue glue
#' @importFrom climateR dap
#' @importFrom httr status_code GET
#' @export
#' @family imerg
#' @examples
#' \dontrun{
#' datetime_utc = as.POSIXct("2023-01-01 16:00:00", tz = "UTC")
#' lon = -105
#' lat = 40
#' gpm <- get_imerg(datetime_utc, lon_obs = lon, lat_obs = lat)
#' }
# Latest version of get IMERG that uses dplyr dataframes to construct the GPM IMERG product and URL
get_imerg <- function(
  datetime_utc = NULL,
  lon_obs      = NULL,
  lat_obs      = NULL,
  product_version = NULL,
  verbose      = FALSE
  ) {

  # check for valid inputs
  if(is.null(datetime_utc)) {
    stop("Missing 'datetime_utc' argument input, 'datetime_utc' must be in format: YYYY-MM-DD HH:MM:SS")
  }

  # check for valid lon_obs input
  if(is.null(lon_obs)) {
    stop("Missing 'lon_obs' argument input, 'lon_obs' must be a numeric LONGITUDE value in CRS 4326")
  }

  # check for valid lat_obs input
  if(is.null(lat_obs)) {
    stop("Missing 'lat_obs' argument input, 'lat_obs' must be a numeric LATITUDE value in CRS 4326")
  }

  # Convert date_of_interest to POSIXct (YYYY-MM-DDTHH:MM:SS.000Z format UTC time)
  dateTime <- as.POSIXct(datetime_utc, format = "%Y-%m-%dT%H:%M:%OS",  tz = "UTC")

  # Since 2024-06-01, IMERG v7 is the dominant HHL data feed
  # Grab the right IMERG version based on date
  # IF the user defines the wrong thing, make the default for them
  product_version <- get_valid_product_version_for_date(product_version, dateTime)

  # list of avaliable GPM IMERG product versions
  versions <- rainOrSnowTools::product_versions

  # throw an error if the product_version is not in the versions list
  if(!product_version %in% names(versions)) {
    stop("Invalid 'product_version' argument, must be one of:\n > ", paste(paste0("'", names(versions), "'"), collapse = "\n > "))
  }

  # Assign GPM variable
  var = 'probabilityLiquidPrecipitation'

  # Observation data is converted into shapefile format
  data = sf::st_as_sf(
    data.frame(datetime_utc, lon_obs, lat_obs),
    coords = c("lon_obs", "lat_obs"),
    crs  = 4326
  )

  # get GPM base URL
  gpm_base_url <- construct_gpm_base_url(datetime_utc, product_version = product_version)

  # if user is using late version, need to ensure the data exists
  if(httr::status_code(httr::GET(gpm_base_url)) == 404 &
     product_version == "GPM_3IMERGHH.07" | product_version == "GPM_3IMERGHH.06"){
    stop("Data for IMERG Final Run for this datetime are not available.")
  }

  # Catalog XML string for base URL
  gpm_catalog <- paste0(gpm_base_url, "catalog.xml")

  # Construct the GPM URL
  gpm_product <- construct_gpm_product(datetime_utc, product_version = product_version)

  # Get the dap paths from the XML catalog.xml file (gpm_catalog)
  final_urls <- get_final_urls(gpm_catalog)

  # get the index of the final_urls that CONTAINS (via grepl()) the "gpm_product" string
  products_index <- grepl(gpm_product, final_urls)

  # If there is a final_urls that contain the "gpm_product" string, then index the final_urls and use the first one
  # Otherwise, if there is NOT a URL that contains the "gpm_product" string, attempt
  #  to get the closest URL (Levenshtein distance) via the get_closest_url() function
  if (any(products_index)) {
    # message("Found a URL that contains the 'gpm_product' string, getting the FIRST URL...")

    # Get the first URL that contains the "gpm_product" string
    product_url <- final_urls[products_index][1]

  } else {

    # message("No final URLs found that contain the 'gpm_product' string, attempting to get the CLOSEST URL...")

    # Get the closest URL to the "gpm_product" string
    product_url <- get_closest_url(final_urls, gpm_product)

  }

  # Print out the GPM base URL, product, and catalog XML
  if(verbose) {
    message("GPM Product URL : ", product_url)
  }

  # Try to get the GPM data using climateR::dap()
  tryCatch({

      # Get Data
      gpm_obs =
        climateR::dap(
          URL     = product_url,
          varname = var,
          AOI     = data,
          verbose = FALSE
        )

      message("Succesfully retrieved GPM data using climateR::dap()")
      message("GPM data column names: ", paste0(names(gpm_obs), collapse = ", "))

      # drop geometry column to make it dataframe
      gpm_obs = sf::st_drop_geometry(gpm_obs)

      # try to use all_of() function to select the variable
      gpm_obs <- tryCatch({
                      gpm_obs %>%
                        dplyr::select(dplyr::all_of((var)))  %>%
                        .[[var]]

                  }, error = function(e) {
                      message("gpm_obs: ", gpm_obs)

                      gpm_obs %>%
                        dplyr::select(probabilityLiquidPrecipitation)  %>%
                        .$probabilityLiquidPrecipitation

                  })

      return(gpm_obs)

    }, error = function(er) {
        message("Error FAILED to get GPM data using climateR::dap() returning NA value...")
        message("Original error message:")
        message(conditionMessage(er))

      # Choose a return value in case of error
      return(NA)

    })

}

