# # R script to be run in Docker container and on AWS Lambda 

# library(dplyr) 
# library(sf)

# # # install with the below code
# devtools::install_github("SnowHydrology/rainOrSnowTools",
#                        ref = "cicd_pipeline")

# library(rainOrSnowTools)
# library(paws)

# -----------------------------------------
# --- ENRICH MRoS AIRTABLE OBSERVATION ----
# -----------------------------------------

library(lambdr)
library(dplyr)

# ENV NASA_DATA_USER=XXXXXXXX
# ENV NASA_DATA_PASSWORD=XXXXXXXX
# climateR::writeNetrc(login = Sys.getenv("NASA_DATA_USER"), password = Sys.getenv("NASA_DATA_PASSWORD"))

# NASA_DATA_USER="XXXXXXXx"
# NASA_DATA_PASSWORD="XXXXXXXX"

# message("NASA_DATA_USER: ", NASA_DATA_USER)
# message("NASA_DATA_PASSWORD: ", NASA_DATA_PASSWORD)
# message("Writing .netrc file...")
# climateR::writeNetrc(login = NASA_DATA_USER, password = NASA_DATA_PASSWORD)
# message("Done writing .netrc file!")

# message("Writing .dodsrc file...")
# climateR::writeDodsrc()
# message("Done writing .dodsrc file!")

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

# # # example JSON string
# event = '{"id": "rec7vrLUoLMeZqfvr",
#     "createdtime": "2023-11-21 23:27:55 UTC",
#     "name": "Rain",
#     "longitude": -79.91447, 
#     "user": "Wi1uG9H7Wp",
#     "latitude": 39.77836,
#     "submitted_time": "23:27:54",
#     "local_time": "18:27:54",
#     "submitted_date": "11/21/23",
#     "local_date": "11/21/23",
#     "comment": "NA",
#     "time": "2023-11-21 23:27:55 UTC"}'

# Take in the above Event, this is approximately what i can expect a single row from 
# the S3 CSV to look like when it enters this lambda function code
sqs_consumer <- function(Records) {

    message("SQS Records: ", Records)


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

    # # run bash script to update netrc file
    # system(update_netrc)

    # input_list <- list(...)
    
    # make sure a .netrc file exists, if not, create one
    if(!climateR::checkNetrc(netrcFile = "/tmp/.netrc")){
        message("Writting a '.netrc' file...")
        message("- login: ", NASA_DATA_USER)
        message("- password: ", NASA_DATA_PASSWORD)
        # climateR::writeNetrc(login = Sys.getenv("NASA_DATA_USER"), password = Sys.getenv("NASA_DATA_PASSWORD"))
        climateR::writeNetrc(login = NASA_DATA_USER, password = NASA_DATA_PASSWORD, netrcFile =  "/tmp/.netrc")
    }
    
    # dodsrcFile = ".dodsrc"
    # netrcFile = "/tmp/.netrc"

    # unlink(dodsrcFile)

    # dir = dirname(dodsrcFile)
    
    # string <- paste0(
    #     'USE_CACHE=0\n',
    #     'MAX_CACHE_SIZE=20\n',
    #     'MAX_CACHED_OBJ=5\n',
    #     'IGNORE_EXPIRES=0\n',
    #     'DEFAULT_EXPIRES=86400\n',
    #     'ALWAYS_VALIDATE=0\n',
    #     'DEFLATE=0\n',
    #     'VALIDATE_SSL=1\n',
    #     paste0('HTTP.COOKIEJAR=/tmp/.urs_cookies\n'),
    #     paste0('HTTP.NETRC=', netrcFile))

    # # create a netrc file
    # write(string, path.expand(dodsrcFile))
    
    # # set the owner-only permission
    # Sys.chmod(dodsrcFile, mode = "755")

    # # create a .dodsrc file
    # x = climateR::writeDodsrc()

    # message("Writting a '.dodsrc' file that references the '.netrc' file")
    
    # message(paste0("found a netrc file, writing dodsrc file to ", x))
    
    # connect to AWS S3 bucket
    s3 <- paws::s3(region = AWS_REGION)

    # # Extract message body
    msg_body = Records[[3]]

    # # Connect to AWS SQS queue client 
    # sqs = paws::sqs(region = AWS_REGION, endpoint = SQS_QUEUE_URL)

    # # # Receive message from SQS queue
    # msg = sqs$receive_message(
    #     QueueUrl            = sqs$get_queue_url(QueueName = SQS_QUEUE_NAME),
    #     MaxNumberOfMessages = 1
    # )

    # # Extract message body
    # msg_body = msg$Messages[[1]]$Body

    message(paste0("Message Body:\n", msg_body))

    message("Parsing SQS trigger event JSON")
    
    # msg_body = '{
    #     "id": "rectFNQPJyLyga6Iq",
    #     "timestamp": "1705589683.0",
    #     "createdtime": "2024-01-18T14:54:43.000Z",
    #     "name": "Snow",
    #     "latitude": "39.64079975903475",
    #     "user": "mehubZKIjJ",
    #     "longitude": "-106.53732056267381",
    #     "submitted_time": "14:54:42",
    #     "local_time": "07:54:42",
    #     "submitted_date": "01/18/24",
    #     "local_date": "1/18/24",
    #     "comment": "nan",
    #     "time": "2024-01-18T14:54:43.000Z"
    # }'

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

    # STEP 5: GET GPM PLP
    plp = rainOrSnowTools::get_imerg(datetime, lon_obs, lat_obs)

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

    # Try and upload file to s3
    tryCatch({
            s3$put_object(
                Body   = paste0("/tmp/", file_name),
                # Body   = paste0("./tmp/", file_name),
                Bucket = S3_BUCKET_NAME,
                Key    = file_name
                )
        },
        error = function(e) {
            message("Error: ", e)
        }
    )

    # s3$put_object(
    #     Body   = paste0("/tmp/", file_name),
    #     Bucket = S3_BUCKET_NAME,
    #     Key    = file_name
    # )
    message("Done!")

#    return(output_json)

}

# library(rainOrSnowTools)
# library(terra)
# library(dplyr)

# sqs_consumer <- function(event) { 
#   sqs_consumer(event) 
#   }

lambdr::start_lambda(config = lambdr::lambda_config(
    environ    = parent.frame()
))