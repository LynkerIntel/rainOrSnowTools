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

# Get the dap paths from the XML catalog.xml file
get_final_urls <- function(url) {

  # read the catalog.xml file from the url
  xml_data <- xml2::read_xml(url)
  message("Length of xml_data: ", length(xml_data))

  # get all the thredds dataset xpaths
  dap_xmls <- 
    xml_data %>% 
    xml2::xml_find_all(glue::glue('////thredds:dataset'))

  message("Number of thredds:dataset nodees: ", length(dap_xmls))
  
  # extract only the "dap" service files
  dap_xmls <- 
    dap_xmls %>%         
    xml2::xml_find_all(glue::glue('///thredds:access[contains(@serviceName, "dap")]'))

  message("Number of thredds:dataset DAP nodes: ", length(dap_xmls))

  message("Extracting attributes from dap_xmls...")

  # extract the attributes from all of the dap_xmls
  dap_attrs <- xml2::xml_attrs(dap_xmls)
  
  message("Extracting URL paths from attributes...")

  # contruct final URLs vector
  dap_paths <- sapply(dap_attrs, function(x) {
    paste0("https://gpm1.gesdisc.eosdis.nasa.gov/opendap/hyrax", x[["urlPath"]])
  })
  
  return(dap_paths)

  # # extract the URL paths from attributes
  # dap_paths <- lapply(dap_attrs, function(x) {
  #   x[["urlPath"]]
  # })

  # # construct final URLs vector
  # final_urls <- sapply(dap_paths, function(x) {
  #   paste0("https://gpm1.gesdisc.eosdis.nasa.gov/opendap/hyrax", x)
  # })

  # return(final_urls)

}

get_imerg3 <- function(datetime_utc,
                        lon_obs,
                        lat_obs) {

  #############################

  # # # Example inputs
  # library(climateR)
  # library(dplyr)
  # library(plyr)
  # library(glue)
  # library(sf)

  # datetime_utc = "2024-01-18 UTC"
  # datetime_utc = datetime
  # datetime_utc = "2024-01-26 UTC"

  #############################

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
  # Assign GPM variable
  var = 'probabilityLiquidPrecipitation'

  # Observation data is converted into shapefile format
  data = sf::st_as_sf(
    data.frame(datetime_utc, lon_obs, lat_obs),
    coords = c("lon_obs", "lat_obs"),
    crs  = 4326
  )

  tryCatch({

      # URL structure
      base = 'https://gpm1.gesdisc.eosdis.nasa.gov/opendap/hyrax/GPM_L3/GPM_3IMERGHHL.06'
      product = '3B-HHR-L.MS.MRG.3IMERG'
      url_trim = '{base}/{year}/{julian}/'
      product_pattern = '{product}.{year}{month}{day}-S{hour}{minTime}00-E{hour}{nasa_time_minute}{nasa_time_second}.{min}.'

      ## Build URLs
      data = 
        data %>%
        dplyr::mutate(dateTime = as.POSIXct(datetime_utc)) %>%
        dplyr::mutate(
          julian  = format(dateTime, "%j"),
          year    = format(dateTime, "%Y"),
          month   = format(dateTime, "%m"),
          day     = format(dateTime, "%d"),
          hour    = sprintf("%02s", format(dateTime, "%H")),
          minTime = sprintf("%02d", plyr::round_any(as.numeric(
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
            "%04d",
            difftime(rounded_time, origin_time,  units = 'min')
          ),
          url_0 = glue::glue(url_trim),
          product_info = glue::glue(product_pattern)
        ) %>%
        dplyr::select(dplyr::any_of(c(
          'datetime_utc', 'url_0', 'product_info'
        )))

      # Visit the XML page to get the right V06[X] values (e.g. C,D,E,...)
      url_base <- paste0(data$url_0, "catalog.xml")
      message("url_base: ", url_base)

      #######################     #######################
      # Get the dap paths from the XML catalog.xml file #
      # NEW VERSION
      #######################     #######################

      # Get the dap paths from the XML catalog.xml file
      final_urls <- get_final_urls(url_base)

      message(glue::glue("{length(final_urls)} total resources found at:\n - '{url_base}'"))

      ## Get Data for the first URL (temporarily, may end up looping through all of them, 
      # and stopping when data is returned)
      gpm_obs =
        climateR::dap(
          URL = final_urls[1],
          varname = var,
          # startDate=as.Date(datetime_utc),
          # endDate=as.Date(datetime_utc),
          AOI = data[1,],
          verbose = TRUE
        )

      # # Loop through each final_url and try to get the data and stop when it works
      # for (i in 1:length(final_urls)) {
      #   message(glue::glue("Final url: {final_urls[i]}"))
      #   message(glue::glue("Trying final_url {i} of {length(final_urls)}..."))
      #   # Try to get the data
      #   gpm_obs <- tryCatch({
      #       climateR::dap(
      #       # gpm_obs <- climateR::dap(
      #       URL = final_urls[i],
      #       varname = var,
      #       AOI = data[1,],
      #       verbose = TRUE
      #     )
      #   }, error = function(e) {
      #     message("Error getting data from final_url: ", e)
      #     message("Trying next final_url...")
      #   })

      #   # Check if gpm_obs is a dataframe
      #   if(is.data.frame(gpm_obs)) {
      #     message("gpm_obs is a dataframe, breaking loop...")
      #     break
      #   }
      # }


      #######################     #######################
      #######################     #######################

      # #######################     #######################
      # # Get the dap paths from the XML catalog.xml file #
      # # OLD version - uncomment BELOW to use
      # #######################     #######################

      # prod <- data$product_info
      # message("prod: ", prod)
      # message("Getting XML data from url base '", url_base, "'")

      # xml_data <- 
      #   xml2::read_xml(url_base) %>%
      #   xml2::xml_find_all(glue::glue('///thredds:dataset[contains(@name, "{prod}")]'))

      # message("Length of xml_data: ", length(xml_data))

      # message("Getting name attribute from xml_data...")

      # prod_name <- xml2::xml_attrs(xml_data[[1]])[["name"]]
      # message("Extracted name from xml (prod_name): ", prod_name)

      # # Create URL
      # final_url = paste0(data$url_0, prod_name)
      # message("final_url: ", final_url)

      # message("Trying to get GPM data using climateR::dap()")
      
      # ## Get Data
      # gpm_obs =
      #   climateR::dap(
      #     URL = final_url,
      #     varname = var,
      #     # startDate=as.Date(datetime_utc),
      #     # endDate=as.Date(datetime_utc),
      #     AOI = data[1,],
      #     verbose = TRUE
      #   )

      # #######################     #######################
      # # OLD version - uncomment ABOVE to use
      # #######################     #######################

      message("Succesfully got GPM data using climateR::dap()")
      message("gpm_obs: ", gpm_obs)

    # gpm_obs = 
    # gpm_obs %>%
    #   sf::st_drop_geometry() %>% # drop geometry column to make it dataframe
    #   dplyr::select(dplyr::all_of((var)))

    # drop geometry column to make it dataframe
    gpm_obs = sf::st_drop_geometry(gpm_obs) 
    
    # try to use all_of() function to select the variable
    gpm_obs <- tryCatch({
                    message("Trying to use all_of() function")

                    gpm_obs %>%
                    dplyr::select(dplyr::all_of((var)))  %>% 
                    .[[var]]

                }, error = function(e) {
                    message("Error using all_of() function", e)
                    message("gpm_obs: ", gpm_obs)

                    gpm_obs %>%
                    dplyr::select(probabilityLiquidPrecipitation)  %>% 
                    .$probabilityLiquidPrecipitation

                })

    #   %>% # drop geometry column to make it dataframe
    #   dplyr::select(dplyr::all_of((var)))

    return(gpm_obs)

  }, error = function(er) {
      message("Original error message:")
      message(conditionMessage(er))

    # Choose a return value in case of error
    NA

  })
}

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

    # Records = 1
    

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

    # message("Updating .netrc file with NASA data credentials...")
    # # update the .netrc file with the NASA data credentials
    # update_netrc <- paste0('#!/bin/bash
    #             # Path to the .netrc file
    #             NETRC_FILE="/lambda/.netrc"
    #             # Replace placeholders with environment variables
    #             sed -i "s/default_user/', NASA_DATA_USER, '/g" "$NETRC_FILE"
    #             sed -i "s/default_password/', NASA_DATA_PASSWORD, '/g" "$NETRC_FILE"
    #             # Output the modified .netrc file
    #             cat "$NETRC_FILE"'
    # )
    message("Adding a log message to confirm GitHub Actions is working v2...")
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
    lon_obs  = as.numeric(data$longitude)
    lat_obs  = as.numeric(data$latitude)
    datetime = as.POSIXct(as.character(data$time), tz = "UTC")
    id       = as.character(data$id)
    
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

    # if state is empty, set to "invalid_location" (this is a placeholder for now)
    state_str = ifelse(state == "character(0)", "invalid_location", state)

    message("Getting GPM PLP data...")

    # STEP 5: GET GPM PLP
    plp = get_imerg3(datetime, lon_obs, lat_obs)
    # plp = rainOrSnowTools::get_imerg_v2(datetime, lon_obs, lat_obs, 6)
    # plp = rainOrSnowTools::get_imerg(datetime, lon_obs, lat_obs)

    # Check if plp is NA, get_imerg_v2() returns NA if there is no data for the given datetime or an error occurs
    if(is.na(plp) || is.null(plp)) {
        message("plp is NA or NULL, giving default value of 9999...")
        # if plp is empty, set to 9999 default value (this is a placeholder for now)
        # plp_val <- 9999
        plp <- 9999

    } 
    #     message("plp is not NA, extracting plp value...")

    #     # extract plp value from the dataframe
    #     plp_val <- plp[['probabilityLiquidPrecipitation']][1]

    #     message("Extracted plp value: ", plp_val, " from plp dataframe")

    #     # if plp is empty, set to 9999 default value (this is a placeholder for now)
    #     plp_val <- ifelse(is.null(plp_val), 9999, plp_val)

    # }

    # if("probabilityLiquidPrecipitation" %in% names(plp)) { } 

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

    # Add placeholder for PLP data
    processed$plp_data = plp

    # Add placeholder for state data
    processed$state = state_str

    # drop id column
    processed = dplyr::select(processed, -id) 
    
    # Add each element in "data" as a column to "processed"
    for (i in 1:length(data)) {
        processed[names(data[i])] = data[i]
    }

    # reorder columns so that "data" columns are first
    processed = 
        processed %>% 
        dplyr::relocate(names(data), .before = 1) 

        
    # convert processed data to JSON
    output_json = jsonlite::toJSON(processed, pretty = TRUE)
    
    # output_json = jsonlite::toJSON(
    #             c(data,
    #             as.list(dplyr::select(processed, -id))
    #             ),
    #  )
    message("Generating hash of message body...")
    msg_hash <- digest::digest(msg_body, algo = "sha256")

    # write JSON to file
    file_name = paste0("mros_staging_", msg_hash, "_", gsub("-", "_", observation_date) , ".json")
    # file_name = paste0("mros_staging_", msg_hash, "_",  gsub("/", "_", data[["submitted_date"]]), ".json") 
    # file_name = paste0("mros_staging_", id, "_",  gsub("/", "_", data[["submitted_date"]]), ".json") 

    # write JSON to file in tmp directory in lambda container
    jsonlite::write_json(output_json, paste0("/tmp/", file_name))
    # jsonlite::write_json(output_json, paste0("./tmp/", file_name))

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
    # #### COMMENTING OUT FOR TESTING #######
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
    # #### COMMENTING OUT FOR TESTING #######
    # #### COMMENTING OUT FOR TESTING #######

    # s3$put_object(
    #     Body   = paste0("/tmp/", file_name),
    #     Bucket = S3_BUCKET_NAME,
    #     Key    = file_name
    # )
    message("Done!")
#    return(output_json)
}

# add_climate_data <- function(event) { 
#   add_climate_data(event) 
#   }

lambdr::start_lambda(config = lambdr::lambda_config(
    environ    = parent.frame()
))

