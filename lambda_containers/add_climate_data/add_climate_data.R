# Author: Angus Watters
# Date: 2024-01-30
# AWS Lambda function to enrich MRoS Airtable observation data with climate data and write the output data as a JSON to an S3 bucket

# The function consumes messages from an AWS SQS queue, with each message containing an Airtable observation (row of the Airtable data)
# The function then retrieves climate and geographic data for each observation and writes the output data as a JSON to an S3 bucket
# enriches the data with climate/geographic data, and then writes the output data as a JSON to an S3 bucket
# The R code here is designed to be Containerized and run as an AWS Lambda function
# When updates are made to the rainOrSnowTools package, the changes to the R package
#  will be realized within this script and the changes will propogate to the AWS data pipeline

# NOTE:
# - Currently NASA GPM IMERG appears to be only avaliable after a 5 day delay, meaning that
# the most recent data is NOT avaliable and this function should only be run to retrieve data from 5 days ago or further back in time

# # # install with the below code
# devtools::install_github("SnowHydrology/rainOrSnowTools",
#                        ref = "cicd_pipeline")

# -----------------------------------------
# --- ENRICH MRoS AIRTABLE OBSERVATION ----
# -----------------------------------------

library(lambdr)
library(dplyr)
# library(sf)
# library(rainOrSnowTools)
# library(climateR)


# Environment variables
NASA_DATA_USER = Sys.getenv("NASA_DATA_USER")
NASA_DATA_PASSWORD = Sys.getenv("NASA_DATA_PASSWORD")
SQS_QUEUE_NAME = Sys.getenv("SQS_QUEUE_NAME")
SQS_QUEUE_URL = Sys.getenv("SQS_QUEUE_URL")
S3_BUCKET_NAME = Sys.getenv("S3_BUCKET_NAME")
AWS_REGION = Sys.getenv("AWS_REGION")

message("=====================================")
message("Environment variables:")
# message("- NASA_DATA_USER: ", NASA_DATA_USER)
# message("- NASA_DATA_PASSWORD: ", NASA_DATA_PASSWORD)
message("- SQS_QUEUE_NAME: ", SQS_QUEUE_NAME)
message("- SQS_QUEUE_URL: ", SQS_QUEUE_URL)
message("- S3_BUCKET_NAME: ", S3_BUCKET_NAME)
message("- AWS_REGION: ", AWS_REGION)
message("=====================================")

# # Get the dap paths from the XML catalog.xml file
# # Description:
#   # This function reads the catalog.xml file from the hyrax GPM IMERG catalog.xml URL and
#   # extracts the "dap" service files, and returns them as a character vector
# # Parameters:
#   # url: character string URL to the catalog.xml file
#   # verbose: logical value to print out messages
# # Returns: vector of final URLs
# get_final_urls <- function(url, verbose = TRUE) {

#   # read the catalog.xml file from the url
#   xml_data <- xml2::read_xml(url)

#   if(verbose) {
#     message("Length of xml_data: ", length(xml_data))
#   }

#   # get all the thredds dataset xpaths
#   dap_xmls <-
#     xml_data %>%
#     xml2::xml_find_all(glue::glue('////thredds:dataset'))

#   if(verbose) {
#     message("Number of thredds:dataset nodees: ", length(dap_xmls))
#   }

#   # extract only the "dap" service files
#   dap_xmls <-
#     dap_xmls %>%
#     xml2::xml_find_all(glue::glue('///thredds:access[contains(@serviceName, "dap")]'))

#   if(verbose) {
#     message("Number of thredds:dataset DAP nodes: ", length(dap_xmls))
#     message("Extracting attributes from dap_xmls...")
#   }

#   # extract the attributes from all of the dap_xmls
#   dap_attrs <- xml2::xml_attrs(dap_xmls)

#   if(verbose) {
#     message("Extracting URL paths from attributes...")
#   }

#   # construct final URLs vector
#   dap_paths <- sapply(dap_attrs, function(x) {
#     paste0("https://gpm1.gesdisc.eosdis.nasa.gov/opendap/hyrax", x[["urlPath"]])
#   })

#   return(dap_paths)

#   # # extract the URL paths from attributes
#   # dap_paths <- lapply(dap_attrs, function(x) {
#   #   x[["urlPath"]]
#   # })

#   # # construct final URLs vector
#   # final_urls <- sapply(dap_paths, function(x) {
#   #   paste0("https://gpm1.gesdisc.eosdis.nasa.gov/opendap/hyrax", x)
#   # })

#   # return(final_urls)

# }

# # Construct the product name of GPM IMERG data for a given date in YYYY-MM-DDTHH:MM:SS.000Z format UTC time
# # date_of_interest - character string date in YYYY-MM-DDTHH:MM:SS.000Z format UTC time (e.g. "2024-01-26T17:16:43.000Z")
# # returns - character GPM IMERG product name for the given date
# construct_gpm_product <- function(date_of_interest) {

#       # date_of_interest = "2024-01-26T17:16:43.000Z"
#       # final_urls

#       # expected_output = c(
#       #   "https://gpm1.gesdisc.eosdis.nasa.gov/opendap/hyrax/GPM_L3/GPM_3IMERGHHL.06/2024/026/3B-HHR-L.MS.MRG.3IMERG.20240126-S170000-E172959.1020.V06E.HDF5",
#       # "https://gpm1.gesdisc.eosdis.nasa.gov/opendap/hyrax/GPM_L3/GPM_3IMERGHHL.06/2024/026/3B-HHR-L.MS.MRG.3IMERG.20240126-S173000-E175959.1050.V06E.HDF5"
#       # )

#       # Define URL structure
#       base <- 'https://gpm1.gesdisc.eosdis.nasa.gov/opendap/hyrax/GPM_L3/GPM_3IMERGHHL.06'
#       product <- '3B-HHR-L.MS.MRG.3IMERG'
#       url_trim <- "{base}/{year}/{julian}/"
#       product_pattern <- "{product}.{year}{month}{day}-S{hour}{minTime}00-E{hour}{nasa_time_minute}{nasa_time_second}.{minutes_diff}."

#       # # Convert date_of_interest to POSIXct
#       dateTime <- as.POSIXct(date_of_interest, format = "%Y-%m-%dT%H:%M:%OS",  tz = "UTC")

#       # Extract necessary date components
#       julian  <- format(dateTime, "%j")
#       year    <- format(dateTime, "%Y")
#       month   <- format(dateTime, "%m")
#       day     <- format(dateTime, "%d")
#       hour    <- sprintf("%02s", format(dateTime, "%H"))
#       minTime <- sprintf("%02d", plyr::round_any(as.numeric(format(dateTime, "%M")), 30, f = floor))

#       # Calculate additional time components
#       origin_time <- as.POSIXct(paste0(format(dateTime, "%Y-%m-%d"), "00:00"), tz = "UTC")
#       rounded_time <- as.POSIXct(paste0(format(dateTime, "%Y-%m-%d"), hour, ":", minTime), tz = "UTC")

#       # Calculate the NASA time components
#       nasa_time <- rounded_time + (29 * 60) + 59
#       nasa_time_minute <- format(nasa_time, "%M")
#       nasa_time_second <- format(nasa_time, "%S")

#       # Calculate the time difference
#       minutes_diff <- sprintf("%04d", difftime(rounded_time, origin_time,  units = 'min'))

#       # Generate base URL and product name
#       url_0 <- glue::glue(url_trim)
#       product_info <- as.character(glue::glue(product_pattern))

#       # # Construct the final URL
#       # output_url <- paste0(url_0, product_info)

#       # Return the constructed product name
#       return(product_info)
#     }

# # Construct the base URL for GPM IMERG data for a given date in YYYY-MM-DDTHH:MM:SS.000Z format UTC time
# # date_of_interest - character string date in YYYY-MM-DDTHH:MM:SS.000Z format UTC time (e.g. "2024-01-26T17:16:43.000Z")
# # returns - character GPM IMERG base URL for the given date
# construct_gpm_base_url <- function(date_of_interest) {

#       # date_of_interest = "2024-01-26T17:16:43.000Z"

#       # Define URL structure
#       base     <- 'https://gpm1.gesdisc.eosdis.nasa.gov/opendap/hyrax/GPM_L3/GPM_3IMERGHHL.06'

#       # character to insert values into via glue::glue()
#       url_trim <- "{base}/{year}/{julian}/"

#       # Convert date_of_interest to POSIXct (YYYY-MM-DDTHH:MM:SS.000Z format UTC time)
#       dateTime <- as.POSIXct(date_of_interest, format = "%Y-%m-%dT%H:%M:%OS",  tz = "UTC")

#       # Extract necessary date components
#       julian  <- format(dateTime, "%j")
#       year    <- format(dateTime, "%Y")

#       # Generate base URL and product name
#       base_url <- as.character(glue::glue(url_trim))

#       # Return the GPM base_url
#       return(base_url)

#     }

# # Get the closest URL to the "match_string" string
# # Description:
#   # Uses the Levenshtein distance to find the closest URL to the "match_string",
#   # match string is the "product name" string determined by the construct_gpm_product() function
# # Parameters:
#   # urls: vector of URLs
#   # match_string: string to match
# # Returns: closest URL to the "match_string"
# get_closest_url <- function(urls, match_string) {
#   # Calculate Levenshtein distances between the "match_string" and "urls"
#   string_distances <- sapply(urls, function(url) {
#     adist(match_string, url)
#   })

#   # Get the index of the minimum distance
#   min_index <- which.min(string_distances)

#   # Return the closest URL
#   return(urls[min_index])
# }

# # TODO: Add this version of get IMERG (get_imerg_latest()) into final version of rainOrSnowTools package to replace the current get_imerg() function
# # Final version of get_imerg4() function
# # Uses construct_gpm_base_url(), construct_gpm_product(), get_final_urls(), and get_closest_url() functions
# # to construct the correct GPM IMERG product and URL and then uses climateR::dap() to retrieve the GPM data
# # Parameters:
#   # datetime_utc: character string date in YYYY-MM-DDTHH:MM:SS.000Z format UTC time
#   # lon_obs: numeric longitude value
#   # lat_obs: numeric latitude value
#   # verbose: logical value to print out messages
# # Returns: GPM IMERG data for the given date and location.
# #         If the data is not found or the climateR::dap() errors out, returns NA
# get_imerg_latest <- function(
#   datetime_utc,
#   lon_obs,
#   lat_obs,
#   verbose = FALSE
#   ) {

#   #############################
#   # # # Example inputs
#   # library(climateR)
#   # library(dplyr)
#   # library(plyr)
#   # library(glue)
#   # library(sf)

#   # datetime_utc = timestamp
#   # datetime_utc = "2024-01-26T17:16:43.000Z"
#   # datetime_utc = "2024-01-26 UTC"
#   # verbose = TRUE
#   #############################

#   # check for valid inputs
#   if(is.null(datetime_utc)) {
#     stop("Missing 'datetime_utc' argument input, 'datetime_utc' must be in format: YYYY-MM-DD HH:MM:SS")
#   }

#   # check for valid lon_obs input
#   if(is.null(lon_obs)) {
#     stop("Missing 'lon_obs' argument input, 'lon_obs' must be a numeric LONGITUDE value in CRS 4326")
#   }

#   # check for valid lat_obs input
#   if(is.null(lat_obs)) {
#     stop("Missing 'lat_obs' argument input, 'lat_obs' must be a numeric LATITUDE value in CRS 4326")
#   }

#   # Assign GPM variable
#   var = 'probabilityLiquidPrecipitation'

#   # Observation data is converted into shapefile format
#   data = sf::st_as_sf(
#     data.frame(datetime_utc, lon_obs, lat_obs),
#     coords = c("lon_obs", "lat_obs"),
#     crs  = 4326
#   )

#   # get GPM base URL
#   gpm_base_url <- construct_gpm_base_url(datetime_utc)

#   # Catalog XML string for base URL
#   gpm_catalog <- paste0(gpm_base_url, "catalog.xml")

#   # Construct the GPM URL
#   gpm_product <- construct_gpm_product(datetime_utc)

#   # Get the dap paths from the XML catalog.xml file (gpm_catalog)
#   final_urls <- get_final_urls(gpm_catalog)

#   # Print out the GPM base URL, product, and catalog XML
#   if(verbose) {
#     message("GPM Base URL: ", gpm_base_url)
#     message("GPM Product: ", gpm_product)
#     message("GPM Catalog XML: ", gpm_catalog)
#     message("Number of URLs on GPM catalog.xml: ", length(final_urls))
#   }

#   # get the index of the final_urls that CONTAINS (via grepl()) the "gpm_product" string
#   products_index <- grepl(gpm_product, final_urls)

#   # If there is a final_urls that contain the "gpm_product" string, then index the final_urls and use the first one
#   # Otherwise, if there is NOT a URL that contains the "gpm_product" string, attempt
#   #  to get the closest URL (Levenshtein distance) via the get_closest_url() function
#   if (any(products_index)) {
#     message("Found a URL that contains the 'gpm_product' string, getting the FIRST URL...")

#     # Get the first URL that contains the "gpm_product" string
#     product_url <- final_urls[products_index][1]

#   } else {

#     message("No final URLs found that contain the 'gpm_product' string, attempting to get the CLOSEST URL...")

#     # Get the closest URL to the "gpm_product" string
#     product_url <- get_closest_url(final_urls, gpm_product)

#   }
#   # Print out the GPM base URL, product, and catalog XML
#   if(verbose) {
#     message("GPM Product URL : ", product_url)
#   }

#   # Try to get the GPM data using climateR::dap()
#   tryCatch({

#       # Get Data
#       gpm_obs =
#         climateR::dap(
#           URL     = product_url,
#           varname = var,
#           AOI     = data,
#           verbose = TRUE
#         )

#       message("Succesfully retrieved GPM data using climateR::dap()")
#       message("GPM data column names: ", paste0(names(gpm_obs), collapse = ", "))

#       # drop geometry column to make it dataframe
#       gpm_obs = sf::st_drop_geometry(gpm_obs)

#       # try to use all_of() function to select the variable
#       gpm_obs <- tryCatch({
#                       message("Trying to use all_of() function")

#                       gpm_obs %>%
#                       dplyr::select(dplyr::all_of((var)))  %>%
#                       .[[var]]

#                   }, error = function(e) {
#                       message("Error using all_of() function", e)
#                       message("gpm_obs: ", gpm_obs)

#                       gpm_obs %>%
#                       dplyr::select(probabilityLiquidPrecipitation)  %>%
#                       .$probabilityLiquidPrecipitation

#                   })

#       return(gpm_obs)

#     }, error = function(er) {
#         message("Error FAILED to get GPM data using climateR::dap() returning NA value...")
#         message("Original error message:")
#         message(conditionMessage(er))

#       # Choose a return value in case of error
#       return(NA)

#     })

#   }

# # Latest version of get IMERG that uses dplyr dataframes to construct the GPM IMERG product and URL
# get_imerg3 <- function(datetime_utc,
#                         lon_obs,
#                         lat_obs,
#                         verbose = FALSE
#                         ) {
#
#   #############################
#
#   # # # Example inputs
#   # library(climateR)
#   # library(dplyr)
#   # library(plyr)
#   # library(glue)
#   # library(sf)
#
#   # datetime_utc = "2024-01-18 UTC"
#   # datetime_utc = datetime
#   # datetime_utc = timestamp
#   # datetime_utc = "2024-01-26T17:16:43.000Z"
#   # datetime_utc = "2024-01-26 UTC"
#
#   #############################
#
#   # check for valid inputs
#   if(is.null(datetime_utc)) {
#     stop("Missing 'datetime_utc' argument input, 'datetime_utc' must be in format: YYYY-MM-DD HH:MM:SS")
#   }
#
#   # check for valid lon_obs input
#   if(is.null(lon_obs)) {
#     stop("Missing 'lon_obs' argument input, 'lon_obs' must be a numeric LONGITUDE value in CRS 4326")
#   }
#
#   # check for valid lat_obs input
#   if(is.null(lat_obs)) {
#     stop("Missing 'lat_obs' argument input, 'lat_obs' must be a numeric LATITUDE value in CRS 4326")
#   }
#   # Assign GPM variable
#   var = 'probabilityLiquidPrecipitation'
#
#   # Observation data is converted into shapefile format
#   data = sf::st_as_sf(
#     data.frame(datetime_utc, lon_obs, lat_obs),
#     coords = c("lon_obs", "lat_obs"),
#     crs  = 4326
#   )
#
#   tryCatch({
#
#       # URL structure
#       base = 'https://gpm1.gesdisc.eosdis.nasa.gov/opendap/hyrax/GPM_L3/GPM_3IMERGHHL.06'
#       product = '3B-HHR-L.MS.MRG.3IMERG'
#       url_trim = '{base}/{year}/{julian}/'
#       product_pattern = '{product}.{year}{month}{day}-S{hour}{minTime}00-E{hour}{nasa_time_minute}{nasa_time_second}.{minutes_diff}.'
#       # product_pattern = '{product}.{year}{month}{day}-S{hour}{minTime}00-E{hour}{nasa_time_minute}{nasa_time_second}.{min}.'
#       ###################
#
#       ## Build URLs
#       data =
#         data %>%
#         # dplyr::mutate(dateTime = as.POSIXct(datetime_utc)) %>%
#         dplyr::mutate(dateTime = as.POSIXct(datetime_utc, format = "%Y-%m-%dT%H:%M:%OS",  tz = "UTC")) %>%
#         dplyr::mutate(
#           julian  = format(dateTime, "%j"),
#           year    = format(dateTime, "%Y"),
#           month   = format(dateTime, "%m"),
#           day     = format(dateTime, "%d"),
#           hour    = sprintf("%02s", format(dateTime, "%H")),
#           minTime = sprintf("%02d", plyr::round_any(as.numeric(
#                       format(dateTime, "%M")
#                     ), 30, f = floor)),
#           origin_time  = as.POSIXct(paste0(
#                             format(dateTime, "%Y-%m-%d"), "00:00"
#                           ), tz = "UTC"),
#           rounded_time = as.POSIXct(paste0(
#             format(dateTime, "%Y-%m-%d"), hour, ":", minTime
#           ), tz = "UTC"),
#           nasa_time        = rounded_time + (29 * 60) + 59,
#           nasa_time_minute = format(nasa_time, "%M"),
#           nasa_time_second = format(nasa_time, "%S"),
#           minutes_diff     = sprintf(
#                                 "%04d",
#                                 difftime(rounded_time, origin_time,  units = 'min')
#                               ),
#           url_0            = glue::glue(url_trim),
#           product_info     = glue::glue(product_pattern)
#         ) %>%
#         dplyr::select(dplyr::any_of(c(
#           'datetime_utc', 'url_0', 'product_info'
#         )))
#
#       # Visit the XML page to get the right V06[X] values (e.g. C,D,E,...)
#       url_base <- paste0(data$url_0, "catalog.xml")
#       message("url_base: ", url_base)
#
#       #######################     #######################
#       # Get the dap paths from the XML catalog.xml file #
#       # NEW VERSION
#       #######################     #######################
#
#       # Get the dap paths from the XML catalog.xml file
#       final_urls <- get_final_urls(url_base)
#
#       # Print out the GPM base URL, product, and catalog XML
#       if(verbose) {
#         message("GPM Base URL: ", data$url_0)
#         message("GPM Product: ", data$product_info)
#         message("GPM Catalog XML: ", url_base)
#         message("Number of URLs on GPM catalog.xml: ", length(final_urls))
#       }
#
#       # find the final_urls that contains the data$product_info
#       product_index <- grep(data$product_info, final_urls)
#
#       # Get the first URL that contains the "product_info" string
#       product_url <- final_urls[product_index][1]
#
#       # Print out the GPM base URL, product, and catalog XML
#       if(verbose) {
#         message("GPM Product URL : ", product_url)
#       }
#
#       message(glue::glue("{length(final_urls)} total resources found at:\n - '{url_base}'"))
#
#       ## Get GPM IMERG PLP Data from the "product_url"
#       gpm_obs =
#         climateR::dap(
#           URL     = product_url,
#           varname = var,
#           AOI     = data,
#           verbose = TRUE
#         )
#
#       message("Succesfully retrieved GPM data using climateR::dap()")
#       message("GPM data column names: ", paste0(names(gpm_obs), collapse = ", "))
#
#     # drop geometry column to make it dataframe
#     gpm_obs = sf::st_drop_geometry(gpm_obs)
#
#     # try to use all_of() function to select the variable
#     gpm_obs <- tryCatch({
#                     message("Trying to use all_of() function")
#
#                     gpm_obs %>%
#                     dplyr::select(dplyr::all_of((var)))  %>%
#                     .[[var]]
#
#                 }, error = function(e) {
#                     message("Error using all_of() function", e)
#                     message("gpm_obs: ", gpm_obs)
#
#                     gpm_obs %>%
#                     dplyr::select(probabilityLiquidPrecipitation)  %>%
#                     .$probabilityLiquidPrecipitation
#
#                 })
#
#     #   %>% # drop geometry column to make it dataframe
#     #   dplyr::select(dplyr::all_of((var)))
#
#     return(gpm_obs)
#
#   }, error = function(er) {
#       message("Original error message:")
#       message(conditionMessage(er))
#
#     # Choose a return value in case of error
#     return(NA)
#
#   })
# }


# # TODO: Move this properly into the rainOrSnowTools package as a function
# add_qaqc_flags = function(df,
#                           snow_max_tair = 10,
#                           rain_max_tair = -5,
#                           rh_min = 30,
#                           max_avgdist_station = 2e5,
#                           max_closest_station = 3e4,
#                           min_n_station = 5,
#                           pval_max = 0.05
#                           ){
#
#   # Add data flags
#   temp_air_snow_max = snow_max_tair
#   temp_air_rain_min = rain_max_tair
#   rh_thresh = rh_min
#   avgdist_thresh = max_avgdist_station
#   closest_thresh = max_closest_station
#   nstation_thresh = min_n_station
#   pval_thresh = pval_max
#
#   qaqc <-
#     df %>%
#     dplyr::mutate(
#       temp_air_flag = dplyr::case_when(
#         temp_air_idw_lapse_var >= temp_air_snow_max &
#           name == "Snow"                              ~ "WarmSnow",
#         temp_air_idw_lapse_var <= temp_air_rain_min &
#           name == "Rain"                              ~ "CoolRain",
#         is.na(temp_air_idw_lapse_var)                  ~ "NoMet",
#         TRUE                                           ~ "Pass"
#         ),
#       rh_flag = dplyr::case_when(
#         rh < rh_thresh ~ "LowRH",
#         is.na(rh)      ~ "NoMet",
#         TRUE           ~ "Pass"
#         ),
#       dist_temp_air_flag = dplyr::case_when(
#         temp_air_avg_dist >= avgdist_thresh  ~ "TooFar",
#         is.na(temp_dew_avg_dist)             ~ "NoMet",
#         TRUE                                 ~ "Pass"
#         ),
#       dist_temp_dew_flag = dplyr::case_when(
#         temp_dew_avg_dist >= avgdist_thresh ~ "TooFar",
#         is.na(temp_dew_avg_dist)            ~ "NoMet",
#         TRUE                                ~ "Pass"
#         ),
#       closest_temp_air_flag = dplyr::case_when(
#         temp_air_nearest_dist >= closest_thresh ~ "TooFar",
#         is.na(temp_air_nearest_dist)            ~ "NoMet",
#         TRUE                                    ~ "Pass"
#         ),
#       closest_temp_dew_flag = dplyr::case_when(
#         temp_dew_nearest_dist >= closest_thresh ~ "TooFar",
#         is.na(temp_dew_nearest_dist)            ~ "NoMet",
#         TRUE                                    ~ "Pass"
#         ),
#       nstation_temp_air_flag = dplyr::case_when(
#         temp_air_n_stations < nstation_thresh   ~ "FewStations",
#         is.na(temp_air_n_stations)              ~ "NoMet",
#         TRUE                                    ~ "Pass"
#         ),
#       nstation_temp_dew_flag = dplyr::case_when(
#         temp_dew_n_stations < nstation_thresh   ~ "FewStations",
#         is.na(temp_dew_n_stations)              ~ "NoMet",
#         TRUE                                    ~ "Pass"
#         ),
#       pval_temp_air_flag = dplyr::case_when(
#         temp_air_lapse_var_pval > pval_thresh ~ "PoorLapse",
#         is.na(temp_air_lapse_var_pval)        ~ "NoMet",
#         TRUE                                  ~ "Pass"
#         ),
#       pval_temp_dew_flag = dplyr::case_when(
#         temp_dew_lapse_var_pval > pval_thresh   ~ "PoorLapse",
#         is.na(temp_dew_lapse_var_pval)          ~ "NoMet",
#         TRUE                                    ~ "Pass"
#         )
#     )  %>%
#     dplyr::mutate(
#       # Checks for phase observations (if it does not )
#       phase_flag = dplyr::case_when(
#         name == "Rain"     ~ "Pass",
#         name == "Mix"      ~ "Pass",
#         name == "Snow"     ~ "Pass",
#         TRUE               ~ "NoPhase"
#         )
#     ) %>%
#     dplyr::mutate(
#       # Checks for if the observation is within CONUS (study boundary)
#       CONUS = dplyr::case_when(
#         state == "Alaska"                                       ~ "NoCONUS",
#         state == "character(0)" | state == "invalid_location"   ~ "NoData",
#         TRUE                                                    ~ "Pass"
#         )
#     )
#
# #   # Note data that have 'NoMet' as part of flag
# #   # Input into another file for further manual review
# #   nomets <-
# #     qaqc %>%
# #     dplyr::filter_all(dplyr::any_vars(. %in% "NoMet"))
#
#   # Store all this in a list for QAQC'ed outputs
#   return(qaqc)
#
# }

# Takes in an SQS Message that contains an Airtable observation (row of the Airtable data)
# and enriches it with climate/geographic data and then writes the output data as a JSON to an S3 bucket
# Example input:
  # msg_body = '{
  #         "id": "xxxxd",
  #         "timestamp": "1706147159.0",
  #         "createdtime": "2024-01-25T01:45:59.000Z",
  #         "name": "Rain",
  #         "latitude": "39.5",
  #         "user": "user_xxxxd",
  #         "longitude": "-120.5",
  #         "submitted_time": "01:45:58",
  #         "local_time": "17:45:58",
  #         "submitted_date": "01/25/24",
  #         "local_date": "1/24/24",
  #         "comment": "nan",
  #         "time": "2024-01-25T01:45:59.000Z",
  #         "duplicate_id": "user_xxxxd_2024_01_25T01_45_59_000Z",
  #         "duplicate_count": "1"
  #     }'
add_climate_data <- function(Records = NULL) {

    ############  ############
    # UNCOMMENT BELOW HERE
    ############  ############

    message("SQS Records: ", Records)

    tryCatch({
        message("Trying to convert Records to JSON")
        message("- jsonlite::fromJSON(Records): ", jsonlite::fromJSON(Records))
    }, error = function(e) {
        message("Error converting Records to JSON: ", e)
    })

    ############  ############
    # UNCOMMENT ABOVE HERE
    ############  ############
    # make sure a .netrc file exists, if not, create one
    if(!climateR::checkNetrc(netrcFile = "/tmp/.netrc")){
        message("Writting a '.netrc' file...")

        # message("- login: ", NASA_DATA_USER)
        # message("- password: ", NASA_DATA_PASSWORD)

        # climateR::writeNetrc(login = Sys.getenv("NASA_DATA_USER"), password = Sys.getenv("NASA_DATA_PASSWORD"))
        climateR::writeNetrc(login = NASA_DATA_USER, password = NASA_DATA_PASSWORD, netrcFile =  "/tmp/.netrc")
    }

    message("Adding a log message to confirm GitHub Actions is working v3...")
    ############  ############
    # UNCOMMENT BELOW HERE
    ############  ############

    message("Connecting to AWS S3 bucket...")
    # message("AWS_REGION: ", AWS_REGION)

    # connect to AWS S3 bucket
    s3 <- paws::s3()
    # s3 <- paws::s3(region = AWS_REGION)

    # # # # Extract message body
    msg_body = Records[[3]]

    ############  ############
    # UNCOMMENT ABOVE HERE
    ############  ############
    ############  ############
    # # Connect to AWS SQS queue client
    # sqs = paws::sqs(region = AWS_REGION, endpoint = SQS_QUEUE_URL)
    # # # Receive message from SQS queue
    # msg = sqs$receive_message(
    #     QueueUrl            = sqs$get_queue_url(QueueName = SQS_QUEUE_NAME),
    #     MaxNumberOfMessages = 1)
    # # Extract message body
    # msg_body = msg$Messages[[1]]$Body
    # ############  ############
    # # remove msg_body BELOW
    ############  ############
        # msg_body = '{
        #         "id": "xxxxd",
        #         "timestamp": "1706147159.0",
        #         "createdtime": "2024-01-25T01:45:59.000Z",
        #         "name": "Rain",
        #         "latitude": "39.5",
        #         "user": "user_xxxxd",
        #         "longitude": "-120.5",
        #         "submitted_time": "01:45:58",
        #         "local_time": "17:45:58",
        #         "submitted_date": "01/25/24",
        #         "local_date": "1/24/24",
        #         "comment": "nan",
        #         "time": "2024-01-25T01:45:59.000Z",
        #         "duplicate_id": "user_xxxxd_2024_01_25T01_45_59_000Z",
        #         "duplicate_count": "1"
        #     }'

    # ############  ############

    message(paste0("Message Body:\n", msg_body))

    message("Parsing SQS trigger event JSON")

    # Convert message body JSON string to list
    data <- jsonlite::fromJSON(msg_body)

    # # Convert JSON string to list
    # data <- jsonlite::fromJSON(event)

    # static inputs
    met_networks  = "ALL"
    degree_filter = 1

    # extract observation data from JSON event
    lon_obs   = as.numeric(data$longitude)
    lat_obs   = as.numeric(data$latitude)
    datetime  = as.POSIXct(as.character(data$time), tz = "UTC")
    timestamp = as.character(data$time)
    id        = as.character(data$id)

    # # get current date for logging
    current_date  = as.character(Sys.Date())
    # current_year  = as.character(format(Sys.Date(), "%Y"))
    # current_month = as.character(format(Sys.Date(), "%m"))
    # current_day   = as.character(format(Sys.Date(), "%d"))

    # convert submitted_date to Date object
    observation_date <- as.Date(data[["submitted_date"]], format = "%m/%d/%y")

    # Extract year, month, and day of the observation
    year  <- format(observation_date, "%Y")
    month <- format(observation_date, "%m")
    day   <- format(observation_date, "%d")

    message("========= Message variables ==========")
    message("- lon_obs: ", lon_obs)
    message("- lat_obs: ", lat_obs)
    message("- datetime: ", datetime)
    message("- timestamp: ", timestamp)
    message("- id: ", id)
    message("- observation_date: ", observation_date)
    message("- current_date: ", current_date)
    message("======================================")

    message("Getting elevation data...")

    # STEP 1: GET ELEVATION
    elev = rainOrSnowTools::get_elev(lon_obs, lat_obs)

    message("Getting eco level 3 data...")

    # STEP 2: GET ECO LEVEL 3
    eco_level3 = rainOrSnowTools:::get_eco_level3(lon_obs, lat_obs)

    message("Getting eco level 4 data...")

    # STEP 3: GET ECO LEVEL 4
    eco_level4 = rainOrSnowTools:::get_eco_level4(lon_obs, lat_obs)

    message("Getting state data...")

    # STEP 4: GET STATE
    state = rainOrSnowTools:::get_state(lon_obs, lat_obs)

    message("Getting GPM PLP data...")

    message("Logging that package has been updated on 02/01/2024 @ 2:55 PM PST...")
    
    # STEP 5: GET GPM PLP
    plp  <- rainOrSnowTools::get_imerg(
                              datetime_utc = timestamp,
                              lon_obs      = lon_obs,
                              lat_obs      = lat_obs,
                              verbose      = TRUE
                              )
    # plp  <- get_imerg_latest(timestamp, lon_obs, lat_obs, verbose = TRUE)
    # plp <- get_imerg3(timestamp, lon_obs, lat_obs, verbose = TRUE)
    # plp <- rainOrSnowTools::get_imerg_v2(datetime, lon_obs, lat_obs, 6)
    # plp <- rainOrSnowTools::get_imerg(datetime, lon_obs, lat_obs)

    # Check if plp is NA, get_imerg_v2() returns NA if there is no data for the given datetime or an error occurs
    if(is.na(plp) || is.null(plp)) {
        message("plp is NA or NULL, giving default value of 9999...")
        # if plp is empty, set to 9999 default value (this is a placeholder for now)
        plp <- 9999

    }

    message("---> FINAL plp: ", plp)

    message("Trying to get meteo data from rainOrSnowTools::access_meteo()")

    # STEP 6: get meteo data
    # get_met_stations + get_met_data
    meteo <- rainOrSnowTools::access_meteo(
        networks         = met_networks,
        datetime_utc_obs = datetime,
        lon_obs          = lon_obs,
        lat_obs          = lat_obs,
        deg_filter       = degree_filter
        )

    # message("--> meteo data: ", meteo)
    message("QCing and processing meteo data...")

    # STEP 7: Process and QA/QC meteo data
    # process_met_data
    # quality control meteo data
    meteo_qc <- rainOrSnowTools::qc_meteo(meteo)

    # subset meteo data to date ...?
    meteo_subset <- rainOrSnowTools:::select_meteo(meteo_qc, datetime)

    # get unique station IDs from "meteo_qc" dataframe
    stations_to_gather <- unique(meteo_qc$id)

    # get metadata for each station ID
    metadata <- rainOrSnowTools::gather_meta(stations_to_gather)

    # taily up number of statons in each network...? and then put into matrix
    station_counts <- cbind(
        "hads_counts" =
            metadata %>%
            dplyr::filter(network == "hads") %>%
            dplyr::tally() %>%
            as.numeric(),
        "lcd_counts" =
            metadata %>%
            dplyr::filter(network == "lcd") %>%
            dplyr::tally() %>%
            as.numeric(),
        "wcc_counts" =
            metadata %>%
            dplyr::filter(network %in% c("snotel", "scan", "snotelt")) %>%
            dplyr::tally() %>%
            as.numeric()
        )

    message("station_counts: ", station_counts)
    message("Modeling meteo data...")

    # STEP 8: Model meteo data and store with station counts
    # model_met_data ----
    # model meteo data and then put into a dataframe with the station counts for the modeled data
    processed = cbind(
                    rainOrSnowTools::model_meteo(
                        id           = id,
                        lon_obs      = lon_obs,
                        lat_obs      = lat_obs,
                        elevation    = elev,
                        datetime_utc = datetime,
                        meteo_df     = meteo_subset,
                        meta_df      = metadata
                    ),
                    station_counts
                    )

    message("Adding plp, elevation, eco level 3, eco level 4, and state data to output data...")

    # Add placeholder for PLP data
    processed$plp = plp

    # round elevation to 2 decimal places
    elev_rounded = round(elev, 2)
    message("- Elevation (rounded): ", elev_rounded)

    # if eco_level3 is empty, set to "invalid_eco_level3" (this is a placeholder for now)
    eco_level3_str = ifelse(eco_level4 == "character(0)", "invalid_eco_level3", eco_level3)
    message("- Eco Level 3: ", eco_level3_str)

    # if eco_level4 is empty, set to "invalid_eco_level4" (this is a placeholder for now)
    eco_level4_str = ifelse(eco_level4 == "character(0)", "invalid_eco_level4", eco_level4)
    message("- Eco Level 4: ", eco_level4_str)

    # if state is empty, set to "invalid_location" (this is a placeholder for now)
    state_str = ifelse(state == "character(0)", "invalid_location", state)
    message("- State: ", state_str)

    # Add elevation, eco level 3, eco level 4, and state data to processed data
    processed$elevation  = elev_rounded
    processed$eco_level3 = eco_level3_str
    processed$eco_level4 = eco_level4_str
    processed$state = state_str

    # drop id column
    processed = dplyr::select(processed, -id)

    # Add each element in "data" as a column to "processed"
    for (i in 1:length(data)) {
        processed[names(data[i])] = data[i]
    }

    message("Adding QA/QC flags to processed data...")

    # Add QA/QC flags to processed data
    processed <- rainOrSnowTools::add_qaqc_flags(df = processed)

    # reorder columns so that "data" columns are first
    processed <-
        processed %>%
        dplyr::relocate(names(data), .before = 1)


    # convert processed data to JSON
    output_json = jsonlite::toJSON(processed, pretty = TRUE)

    message("Generating hash of message body...")
    msg_hash <- digest::digest(msg_body, algo = "sha256")

    # write JSON to file
    file_name = paste0("mros_staging_", msg_hash, "_", gsub("-", "_", observation_date) , ".json")
    # file_name = paste0("mros_staging_", msg_hash, "_",  gsub("/", "_", data[["submitted_date"]]), ".json")

    # write JSON to file in tmp directory in lambda container
    jsonlite::write_json(output_json, paste0("/tmp/", file_name))

    # Create S3 object key for the output file
    S3_OUTPUT_OBJECT_KEY = paste0(
                            year, "/",
                            month, "/",
                            day, "/",
                            gsub("-", "_", current_date), "/",  # day the function was run
                            file_name
                            )

    message(
      paste0(
        "Calling S3 PutObject:\n- '", file_name,
        "'\n- Object location: ", paste0("/tmp/", file_name),
        "'\n- S3_OUTPUT_OBJECT_KEY: '",S3_OUTPUT_OBJECT_KEY, "'"
        )
      )
    # jsonlite::read_json(paste0("/tmp/", file_name))

    # #### COMMENTING OUT FOR TESTING #######
    # Try and upload file to s3
    tryCatch({
            s3$put_object(
                Body   = paste0("/tmp/", file_name),
                # Body   = paste0("./tmp/", file_name),
                Bucket = S3_BUCKET_NAME,
                Key    = S3_OUTPUT_OBJECT_KEY
                # Key    = file_name
                )
        },
        error = function(e) {
            message("Error: ", e)
        }
    )

    # #### COMMENTING OUT FOR TESTING #######

    message("Done!")
#    return(output_json)
}

lambdr::start_lambda(config = lambdr::lambda_config(
    environ    = parent.frame()
))

