# # R script to be run in Docker container and on AWS Lambda 

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
message("- NASA_DATA_USER: ", NASA_DATA_USER)
message("- NASA_DATA_PASSWORD: ", NASA_DATA_PASSWORD)
message("- SQS_QUEUE_NAME: ", SQS_QUEUE_NAME)
message("- SQS_QUEUE_URL: ", SQS_QUEUE_URL)
message("- S3_BUCKET_NAME: ", S3_BUCKET_NAME)
message("- AWS_REGION: ", AWS_REGION)
message("=====================================")

get_imerg3 <- function(datetime_utc,
                        lon_obs,
                        lat_obs) {

  #############################

  # # Example inputs
  # library(climateR)
  # library(dplyr)
  # library(plyr)
  # library(glue)
  # library(sf)

  # # datetime_utc = "2024-01-18 UTC"
#   datetime_utc = "2023-11-21 UTC"
#   lon_obs =-79.91447
#   lat_obs= 39.77836
  # version = 6
    # datetime_utc = datetime
        # datetime_utc = "2024-01-25 UTC"
    # lon_obs
    # lat_obs

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

    #   url_base = "https://gpm1.gesdisc.eosdis.nasa.gov/opendap/hyrax/GPM_L3/GPM_3IMERGHHL.06/2024/025/catalog.xml"

      prod <- data$product_info
      message("prod: ", prod)
      message("Getting XML data from url base '", url_base, "'")

      xml_data <- 
        xml2::read_xml(url_base) %>%
        xml2::xml_find_all(glue::glue('///thredds:dataset[contains(@name, "{prod}")]'))

      message("Length of xml_data: ", length(xml_data))

      message("Getting name attribute from xml_data...")

      prod_name <- xml2::xml_attrs(xml_data[[1]])[["name"]]
      message("Extracted name from xml (prod_name): ", prod_name)

      # Create URL
      final_url = paste0(data$url_0, prod_name)
      message("final_url: ", final_url)

      message("Trying to get GPM data using climateR::dap()")
      ## Get Data
      gpm_obs =
        climateR::dap(
          URL = final_url,
          varname = var,
          AOI = data[1,],
          verbose = TRUE
        )

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
                    dplyr::select(dplyr::all_of((var)))

                }, error = function(e) {
                    message("Error using all_of() function", e)
                    message("gpm_obs: ", gpm_obs)

                    gpm_obs %>%
                    dplyr::select(probabilityLiquidPrecipitation)

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

# Take in the above Event, this is approximately what i can expect a single row from 
# the S3 CSV to look like when it enters this lambda function code
sqs_consumer <- function(Records = NULL) {
    ############  ############
    # UNCOMMENT BELOW HERE
    ############  ############

    message("SQS Records: ", Records)
    
    ############  ############
    # UNCOMMENT ABOVE HERE
    ############  ############
    # make sure a .netrc file exists, if not, create one
    if(!climateR::checkNetrc(netrcFile = "/tmp/.netrc")){
        message("Writting a '.netrc' file...")
        message("- login: ", NASA_DATA_USER)
        message("- password: ", NASA_DATA_PASSWORD)
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

    ############  ############
    # UNCOMMENT BELOW HERE
    ############  ############

    # connect to AWS S3 bucket
    s3 <- paws::s3(region = AWS_REGION)

    # # Extract message body
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
    #     MaxNumberOfMessages = 1
    # )

    # # Extract message body
    # msg_body = msg$Messages[[1]]$Body

    # ############  ############
    #     # remove msg_body BELOW
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

    message("========= Message variables ==========")
    message("- lon_obs: ", lon_obs)
    message("- lat_obs: ", lat_obs)
    message("- datetime: ", datetime)
    message("- id: ", id)
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
    if(is.na(plp)) {
        message("plp is NA, giving default value of 9999...")
        # if plp is empty, set to 9999 default value (this is a placeholder for now)
        plp_val <- 9999

    } else {
        message("plp is not NA, extracting plp value...")

        # extract plp value from the dataframe
        plp_val <- plp[['probabilityLiquidPrecipitation']][1]

        message("Extracted plp value: ", plp_val, " from plp dataframe")

        # if plp is empty, set to 9999 default value (this is a placeholder for now)
        plp_val <- ifelse(is.null(plp_val), 9999, plp_val)
    }

    # if("probabilityLiquidPrecipitation" %in% names(plp)) { } 

    message("---> Final plp_val: ", plp_val)

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
    processed$plp_data = plp_val

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

    # write JSON to file
    file_name = paste0("mros_staging_", id, "_",  gsub("/", "_", data[["submitted_date"]]), ".json") 

    # write JSON to file in tmp directory in lambda container
    jsonlite::write_json(output_json, paste0("/tmp/", file_name))
    # jsonlite::write_json(output_json, paste0("./tmp/", file_name))
    
    message(paste0("Calling S3 PutObject:\n- '", file_name, "'\n- S3 Object: ", paste0("/tmp/", file_name)))
    # jsonlite::read_json(paste0("/tmp/", file_name))

    # #### COMMENTING OUT FOR TESTING #######
    # #### COMMENTING OUT FOR TESTING #######
    # #### COMMENTING OUT FOR TESTING #######
    # # Try and upload file to s3
    # tryCatch({
    #         s3$put_object(
    #             Body   = paste0("/tmp/", file_name),
    #             # Body   = paste0("./tmp/", file_name),
    #             Bucket = S3_BUCKET_NAME,
    #             Key    = file_name
    #             )
    #     },
    #     error = function(e) {
    #         message("Error: ", e)
    #     }
    # )

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

# sqs_consumer <- function(event) { 
#   sqs_consumer(event) 
#   }

lambdr::start_lambda(config = lambdr::lambda_config(
    environ    = parent.frame()
))

