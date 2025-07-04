# Author: Angus Watters
# Date written: 2024-01-30
# Date updated: 2025-06-01
# AWS Lambda function to enrich MRoS Airtable observation data with climate data and write the output data as a JSON to an S3 bucket

# The function consumes messages from an AWS SQS queue, with each message containing an Airtable observation (row of the Airtable data)
# The function then retrieves climate and geographic data for each observation and writes the output data as a JSON to an S3 bucket
# enriches the data with climate/geographic data, and then writes the output data as a JSON to an S3 bucket
# The R code here is designed to be Containerized and run as an AWS Lambda function
# When updates are made to the rainOrSnowTools package, the changes to the R package
#  will be realized within this script and the changes will propogate to the AWS data pipeline

# NOTE:
# - Currently NASA GPM IMERG appears to be only avaliable after a 5 day delay, meaning that
# the most recent data is NOT available and this function should only be run to retrieve data from 5 days ago or further back in time

# -----------------------------------------
# --- ENRICH MRoS AIRTABLE OBSERVATION ----
# -----------------------------------------

library(lambdr)
library(dplyr)

# Environment variables
NASA_DATA_USER = Sys.getenv("NASA_DATA_USER")
NASA_DATA_PASSWORD = Sys.getenv("NASA_DATA_PASSWORD")
SQS_QUEUE_NAME = Sys.getenv("SQS_QUEUE_NAME")
SQS_QUEUE_URL = Sys.getenv("SQS_QUEUE_URL")
S3_BUCKET_NAME = Sys.getenv("S3_BUCKET_NAME")
AWS_REGION = Sys.getenv("AWS_REGION")

message("=====================================")
message("Environment variables:")
message("- SQS_QUEUE_NAME: ", SQS_QUEUE_NAME)
message("- SQS_QUEUE_URL: ", SQS_QUEUE_URL)
message("- S3_BUCKET_NAME: ", S3_BUCKET_NAME)
message("- AWS_REGION: ", AWS_REGION)
message("=====================================")

# Takes in an SQS Message that contains an Airtable observation (row of the Airtable data)
# and enriches it with climate/geographic data and then writes the output data as a JSON to an S3 bucket

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

        climateR::writeNetrc(login = NASA_DATA_USER, password = NASA_DATA_PASSWORD, netrcFile =  "/tmp/.netrc")
    }

    message("Adding a log message to confirm GitHub Actions is working v3...")

    message("Connecting to AWS S3 bucket...")

    # connect to AWS S3 bucket
    s3 <- paws::s3()

    # Extract message body
    msg_body = Records[[3]]

    ############  ############

        empty_processed_df <- data.frame(
                # id = character(),
                # timestamp = numeric(),
                # createdtime = character(),
                # name = character(),
                # latitude = numeric(),
                # user = character(),
                # longitude = numeric(),
                # submitted_time = character(),
                # local_time = character(),
                # submitted_date = character(),
                # local_date = character(),
                # comment = character(),
                # time = character(),
                # device_type = character(),
                # duplicate_id = character(),
                # duplicate_count = numeric(),
                temp_air_idw_lapse_const = numeric(),
                temp_air_idw_lapse_var = numeric(),
                temp_air_nearest_site_const = numeric(),
                temp_air_nearest_site_var = numeric(),
                temp_air_avg_obs = numeric(),
                temp_air_min_obs = numeric(),
                temp_air_max_obs = numeric(),
                temp_air_lapse_var = numeric(),
                temp_air_lapse_var_r2 = numeric(),
                temp_air_lapse_var_pval = numeric(),
                temp_air_n_stations = numeric(),
                temp_air_avg_time_gap = numeric(),
                temp_air_avg_dist = numeric(),
                temp_air_nearest_id = character(),
                temp_air_nearest_elev = numeric(),
                temp_air_nearest_dist = numeric(),
                temp_air_nearest = numeric(),
                temp_dew_idw_lapse_const = numeric(),
                temp_dew_idw_lapse_var = numeric(),
                temp_dew_nearest_site_const = numeric(),
                temp_dew_nearest_site_var = numeric(),
                temp_dew_avg_obs = numeric(),
                temp_dew_min_obs = numeric(),
                temp_dew_max_obs = numeric(),
                temp_dew_lapse_var = numeric(),
                temp_dew_lapse_var_r2 = numeric(),
                temp_dew_lapse_var_pval = numeric(),
                temp_dew_n_stations = numeric(),
                temp_dew_avg_time_gap = numeric(),
                temp_dew_avg_dist = numeric(),
                temp_dew_nearest_id = character(),
                temp_dew_nearest_elev = numeric(),
                temp_dew_nearest_dist = numeric(),
                temp_dew_nearest = numeric(),
                rh = numeric(),
                temp_wet = numeric(),
                hads_counts = numeric(),
                lcd_counts = numeric(),
                wcc_counts = numeric(),
                plp = numeric(),
                elevation = numeric(),
                eco_level3 = character(),
                eco_level4 = character(),
                state = character(),
                temp_air_flag = character(),
                rh_flag = character(),
                dist_temp_air_flag = character(),
                dist_temp_dew_flag = character(),
                closest_temp_air_flag = character(),
                closest_temp_dew_flag = character(),
                nstation_temp_air_flag = character(),
                nstation_temp_dew_flag = character(),
                pval_temp_air_flag = character(),
                pval_temp_dew_flag = character(),
                phase_flag = character(),
                CONUS = character(),
                comment_flag = character(),
                met1_id = character(),
                met1_temp_air_idw_lapse_const = numeric(),
                met1_temp_air_idw_lapse_var = numeric(),
                met1_temp_air_nearest_site_const = numeric(),
                met1_temp_air_nearest_site_var = numeric(),
                met1_temp_air_avg_obs = numeric(),
                met1_temp_air_min_obs = numeric(),
                met1_temp_air_max_obs = numeric(),
                met1_temp_air_lapse_var = numeric(),
                met1_temp_air_lapse_var_r2 = numeric(),
                met1_temp_air_lapse_var_pval = numeric(),
                met1_temp_air_n_stations = numeric(),
                met1_temp_air_avg_time_gap = numeric(),
                met1_temp_air_avg_dist = numeric(),
                met1_temp_air_nearest_id = character(),
                met1_temp_air_nearest_elev = numeric(),
                met1_temp_air_nearest_dist = numeric(),
                met1_temp_air_nearest = numeric(),
                met1_temp_dew_idw_lapse_const = numeric(),
                met1_temp_dew_idw_lapse_var = numeric(),
                met1_temp_dew_nearest_site_const = numeric(),
                met1_temp_dew_nearest_site_var = numeric(),
                met1_temp_dew_avg_obs = numeric(),
                met1_temp_dew_min_obs = numeric(),
                met1_temp_dew_max_obs = numeric(),
                met1_temp_dew_lapse_var = numeric(),
                met1_temp_dew_lapse_var_r2 = numeric(),
                met1_temp_dew_lapse_var_pval = numeric(),
                met1_temp_dew_n_stations = numeric(),
                met1_temp_dew_avg_time_gap = numeric(),
                met1_temp_dew_avg_dist = numeric(),
                met1_temp_dew_nearest_id = character(),
                met1_temp_dew_nearest_elev = numeric(),
                met1_temp_dew_nearest_dist = numeric(),
                met1_temp_dew_nearest = numeric(),
                met1_rh = numeric(),
                met1_temp_wet = numeric(),
                met1_hads_counts = numeric(),
                met1_lcd_counts = numeric(),
                met1_wcc_counts = numeric(),
                met1_id_raw = character(),
                met1_datetime_raw = character(),
                met1_temp_air_raw = numeric(),
                met1_temp_dew_raw = numeric(),
                met1_rh_raw = numeric(),
                met1_temp_wet_raw = numeric(),
                met2_id = character(),
                met2_temp_air_idw_lapse_const = numeric(),
                met2_temp_air_idw_lapse_var = numeric(),
                met2_temp_air_nearest_site_const = numeric(),
                met2_temp_air_nearest_site_var = numeric(),
                met2_temp_air_avg_obs = numeric(),
                met2_temp_air_min_obs = numeric(),
                met2_temp_air_max_obs = numeric(),
                met2_temp_air_lapse_var = numeric(),
                met2_temp_air_lapse_var_r2 = numeric(),
                met2_temp_air_lapse_var_pval = numeric(),
                met2_temp_air_n_stations = numeric(),
                met2_temp_air_avg_time_gap = numeric(),
                met2_temp_air_avg_dist = numeric(),
                met2_temp_air_nearest_id = character(),
                met2_temp_air_nearest_elev = numeric(),
                met2_temp_air_nearest_dist = numeric(),
                met2_temp_air_nearest = numeric(),
                met2_temp_dew_idw_lapse_const = numeric(),
                met2_temp_dew_idw_lapse_var = numeric(),
                met2_temp_dew_nearest_site_const = numeric(),
                met2_temp_dew_nearest_site_var = numeric(),
                met2_temp_dew_avg_obs = numeric(),
                met2_temp_dew_min_obs = numeric(),
                met2_temp_dew_max_obs = numeric(),
                met2_temp_dew_lapse_var = numeric(),
                met2_temp_dew_lapse_var_r2 = numeric(),
                met2_temp_dew_lapse_var_pval = numeric(),
                met2_temp_dew_n_stations = numeric(),
                met2_temp_dew_avg_time_gap = numeric(),
                met2_temp_dew_avg_dist = numeric(),
                met2_temp_dew_nearest_id = character(),
                met2_temp_dew_nearest_elev = numeric(),
                met2_temp_dew_nearest_dist = numeric(),
                met2_temp_dew_nearest = numeric(),
                met2_rh = numeric(),
                met2_temp_wet = numeric(),
                met2_hads_counts = numeric(),
                met2_lcd_counts = numeric(),
                met2_wcc_counts = numeric(),
                met2_id_raw = character(),
                met2_datetime_raw = character(),
                met2_temp_air_raw = numeric(),
                met2_rh_raw = numeric()
                )

    empty_processed_df[1,] <- NA  # This will set all numeric columns to NA and character columns to ""

    message(paste0("Message Body:\n", msg_body))

    message("Parsing SQS trigger event JSON")

    # Convert message body JSON string to list
    data <- jsonlite::fromJSON(msg_body)

    # static inputs
    met_networks        = "ALL"
    degree_filter       = 1
    gpm_product_version = "GPM_3IMERGHHL.07"

    # extract observation data from JSON event
    lon_obs   = as.numeric(data$longitude)
    lat_obs   = as.numeric(data$latitude)
    datetime  = as.POSIXct(as.character(data$time), format = "%Y-%m-%dT%H:%M:%OSZ", tz = "UTC")
    # timestamp = as.character(data$time)
    id        = as.character(data$id)

    # # get current date for logging
    current_date  = as.character(Sys.Date())

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

    message("Getting GPM PLP data...")

    message("Logging that package has been updated on 06/25/2024 @ 2:45 PM PST...")
    # STEP 5: GET GPM PLP
    plp <- tryCatch({
                rainOrSnowTools::get_imerg(
                    datetime_utc    = datetime,
                    lon_obs         = lon_obs,
                    lat_obs         = lat_obs,
                    product_version = gpm_product_version,
                    verbose         = TRUE
                )
            },
            error = function(e) {
                message("An error occurred: ", e$message)
                9999
                })

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

    if (nrow(meteo) > 0) {
        message("Meteo data retrieved successfully")

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
        # processed  %>% names()
        message("Adding plp, elevation, eco level 3, eco level 4, and state data to output data...")

        # Add placeholder for PLP data
        processed$plp = plp

        # round elevation to 2 decimal places
        elev_rounded = round(elev, 2)
        message("- Elevation (rounded): ", elev_rounded)

        # if eco_level3 is empty, set to "invalid_eco_level3" (this is a placeholder for now)
        eco_level3_str = ifelse(eco_level3 == "character(0)", "invalid_eco_level3", eco_level3)
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

        #############################################################
        ####################### Validation code #####################
        #############################################################

        ## validate_met_data 1 ## ----
        # Now validate station data
        # Randomly select one station from meteo

        # get a random station, its ID and metadata
        random_station = meteo_qc[sample(nrow(meteo_qc), 1), ]
        random_id = as.character(random_station["id"])
        random_metadata = rainOrSnowTools::gather_meta(random_id)

        # get the lon, lat, elev, and datetime of the random station
        st_lon = as.numeric(random_metadata[1, "lon"])
        st_lat = as.numeric(random_metadata[1, "lat"])
        st_elev = as.numeric(random_metadata[1, "elev"])
        st_datetime = as.POSIXct(as.character(random_station[1, "datetime"]), tz = "UTC")

        # Use these information to re-gather the meteo/etc
        st_meteo <- rainOrSnowTools::access_meteo(
            networks = met_networks,
            datetime_utc_obs = st_datetime,
            lon_obs = st_lon,
            lat_obs = st_lat,
            deg_filter = degree_filter
        )

        # Take out the closest station data
        st_meteo <-
            st_meteo %>%
            dplyr::filter(id != random_id)

        # QC the random stations meteo data
        random_meteo_qc <- rainOrSnowTools::qc_meteo(st_meteo)

        # stash the meteo dataframe to feed into "model_meteo" in a few steps
        random_meteo_df <- rainOrSnowTools:::select_meteo(random_meteo_qc, st_datetime)

        # get the IDs of stations to gather
        st_stations_to_gather <- unique(random_meteo_qc$id)

        # gather the meta data for the stations (minus the random station)
        st_metadata_minus_random <- rainOrSnowTools::gather_meta(st_stations_to_gather)

        random_station_counts = cbind(
            "hads_counts" =
                st_metadata_minus_random %>%
                dplyr::filter(network == "hads") %>%
                dplyr::tally() %>%
                as.numeric(),
            "lcd_counts" =
                st_metadata_minus_random %>%
                dplyr::filter(network == "lcd") %>%
                dplyr::tally() %>%
                as.numeric(),
            "wcc_counts" =
                st_metadata_minus_random %>%
                dplyr::filter(network %in% c("snotel", "scan", "snotelt")) %>%
                dplyr::tally() %>%
                as.numeric()
        )

        # validate the meteo data
        validated_met = cbind(
                        rainOrSnowTools::model_meteo(
                            id           = random_id,
                            lon_obs      = st_lon,
                            lat_obs      = st_lat,
                            elevation    = st_elev,
                            datetime_utc = st_datetime,
                            meteo_df     = random_meteo_df,
                            meta_df      = st_metadata_minus_random
                        ),
                        random_station_counts,
                        random_station %>%
                        dplyr::rename_with(~paste0(.x, "_raw"), everything())
                        )

        names(validated_met) = paste0("met1_", names(validated_met))

        ## validate_met_data 2 ## #########

        # Stations with humidity vars, if none,
        valid_data = tryCatch({
                meteo_qc %>%
                filter(!dplyr::if_any(c(temp_air, rh, temp_dew), is.na))
            }, error = function(e) {
                meteo_qc %>%
                filter(!dplyr::if_any(c(temp_air, rh), is.na))
            }, error = function(e){
                meteo_qc %>%
                filter(!dplyr::if_any(temp_air, is.na))
            })

        valid_data = if (nrow(valid_data) == 0){
            meteo_qc %>%
            filter(!dplyr::if_any(c(temp_air, rh), is.na))
            } else {
            valid_data = valid_data
            }

        # get a random SECOND station, its ID and metadata
        random_station2 = meteo_qc[sample(nrow(valid_data), 1), ]
        random_id2 = as.character(random_station2["id"])
        random_metadata2 = rainOrSnowTools::gather_meta(random_id2)

        # get the lon, lat, elev, and datetime of the random station
        st_lon2 = as.numeric(random_metadata2[1, "lon"])
        st_lat2 = as.numeric(random_metadata2[1, "lat"])
        st_elev2 = as.numeric(random_metadata2[1, "elev"])
        st_datetime2 = as.POSIXct(as.character(random_station2[1, "datetime"]), tz = "UTC")

        # Use these information to re-gather the meteo/etc
        st_meteo2 <- rainOrSnowTools::access_meteo(
            networks = met_networks,
            datetime_utc_obs = st_datetime2,
            lon_obs = st_lon2,
            lat_obs = st_lat2,
            deg_filter = degree_filter
        )

        # Take out the closest station data
        st_meteo2 <-
            st_meteo2 %>%
            dplyr::filter(id != random_id2)

        # QC the random stations meteo data
        random_meteo_qc2 <- rainOrSnowTools::qc_meteo(st_meteo2)

        # stash the meteo dataframe to feed into "model_meteo" in a few steps
        random_meteo_df2 <- rainOrSnowTools:::select_meteo(random_meteo_qc2, st_datetime2)

        # get the IDs of stations to gather
        st_stations_to_gather2 <- unique(random_meteo_qc2$id)

        # gather the meta data for the stations (minus the random station)
        st_metadata_minus_random2 <- rainOrSnowTools::gather_meta(st_stations_to_gather2)

        random_station_counts2 = cbind(
            "hads_counts" =
                st_metadata_minus_random2 %>%
                dplyr::filter(network == "hads") %>%
                dplyr::tally() %>%
                as.numeric(),
            "lcd_counts" =
                st_metadata_minus_random2 %>%
                dplyr::filter(network == "lcd") %>%
                dplyr::tally() %>%
                as.numeric(),
            "wcc_counts" =
                st_metadata_minus_random2 %>%
                dplyr::filter(network %in% c("snotel", "scan", "snotelt")) %>%
                dplyr::tally() %>%
                as.numeric()
                )

        # validate the meteo data for the second station
        validated_met2 = cbind(
                        rainOrSnowTools::model_meteo(
                            id           = random_id2,
                            lon_obs      = st_lon2,
                            lat_obs      = st_lat2,
                            elevation    = st_elev2,
                            datetime_utc = st_datetime2,
                            meteo_df     = random_meteo_df2,
                            meta_df      = st_metadata_minus_random2
                        ),
                        random_station_counts2,
                        random_station2 %>%
                        dplyr::rename_with(~paste0(.x, "_raw"), everything())
                        )

        names(validated_met2) = paste0("met2_", names(validated_met2))


        ###### BIND THE 2 validations into a single dataframe #######
        validated_meteo = cbind(validated_met, validated_met2)

        ##### ADD THE VALIDATED METEO DATA TO THE PROCESSED DATAFRAME #####
        processed = cbind(processed, validated_meteo)

        # convert processed data to JSON
        output_json = jsonlite::toJSON(processed, pretty = TRUE)

    } else {

        message("Adding plp, elevation, eco level 3, eco level 4, and state data to output data...")

        # Add placeholder for PLP data
        empty_processed_df$plp = plp

        # round elevation to 2 decimal places
        elev_rounded = round(elev, 2)
        message("- Elevation (rounded): ", elev_rounded)

        # if eco_level3 is empty, set to "invalid_eco_level3" (this is a placeholder for now)
        eco_level3_str = ifelse(eco_level3 == "character(0)", "invalid_eco_level3", eco_level3)
        message("- Eco Level 3: ", eco_level3_str)

        # if eco_level4 is empty, set to "invalid_eco_level4" (this is a placeholder for now)
        eco_level4_str = ifelse(eco_level4 == "character(0)", "invalid_eco_level4", eco_level4)
        message("- Eco Level 4: ", eco_level4_str)

        # if state is empty, set to "invalid_location" (this is a placeholder for now)
        state_str = ifelse(state == "character(0)", "invalid_location", state)
        message("- State: ", state_str)

        # Add elevation, eco level 3, eco level 4, and state data to processed data
        empty_processed_df$elevation  = elev_rounded
        empty_processed_df$eco_level3 = eco_level3_str
        empty_processed_df$eco_level4 = eco_level4_str
        empty_processed_df$state = state_str

        # Add each element in "data" as a column to "processed"
        for (i in 1:length(data)) {
            message("Adding data to empty_processed_df...")
            message("- names(data[i]): ", names(data[i]))
            empty_processed_df[names(data[i])] = data[i]
        }

        # reorder columns so that "data" columns are first
        empty_processed_df <-
            empty_processed_df %>%
            dplyr::relocate(names(data), .before = 1)

        empty_processed_df <-
            empty_processed_df %>%
            dplyr::mutate(across(everything(), ~ifelse(is.na(.), paste0("invalid"), .)))

        output_json = jsonlite::toJSON(empty_processed_df, pretty = TRUE)

    }

    #############################################################
    #############################################################

    message("Generating hash of message body...")
    msg_hash <- digest::digest(msg_body, algo = "sha256")

    # write JSON to file
    file_name = paste0("mros_staging_", msg_hash, "_", gsub("-", "_", observation_date) , ".json")

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

    #### COMMENTING OUT FOR TESTING #######

    # Try and upload file to s3
    tryCatch({
            s3$put_object(
                Body   = paste0("/tmp/", file_name),
                Bucket = S3_BUCKET_NAME,
                Key    = S3_OUTPUT_OBJECT_KEY
                )
        },
        error = function(e) {
            message("Error: ", e)
        }
    )

    #### COMMENTING OUT FOR TESTING #######

    message("Done!")
}

lambdr::start_lambda(config = lambdr::lambda_config(
    environ    = parent.frame()
))

