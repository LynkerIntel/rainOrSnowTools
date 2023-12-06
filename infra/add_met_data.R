# # Clean script for Mountain Rain or Snow observation processing.
# # This goes through modeling met variables (air/dew/wet temperature,
# # and relative humidity) for each observation.
#
# # Then goes through validating the modeling process by evaluating the
# # met stations (take a station out, and see how well the model works,
# # compare the raw and the modeled data)
#
# # load package
# # have this script in the package folder
# devtools::load_all()

# library(dplyr) 
# library(sf)

# # install with the below code
# devtools::install_github("SnowHydrology/rainOrSnowTools",
#                          ref = "cicd_pipeline")

# library(rainOrSnowTools)
# -----------------------------------------
# --- ENRICH MRoS AIRTABLE OBSERVATION ----
# -----------------------------------------
# example JSON string
event = '{"id": "rec7vrLUoLMeZqfvr",
    "createdtime": "2023-11-21 23:27:55 UTC",
    "name": "Rain",
    "longitude": -79.91447, 
    "user": "Wi1uG9H7Wp",
    "latitude": 39.77836,
    "submitted_time": "23:27:54",
    "local_time": "18:27:54",
    "submitted_date": "11/21/23",
    "local_date": "11/21/23",
    "comment": "NA",
    "time": "2023-11-21 23:27:55 UTC"}'

# Take in the above Event, this is approximately what i can expect a single row from 
# the S3 CSV to look like when it enters this lambda function code
add_met_to_obs <- function(event) {

    # Convert JSON string to list
    data <- jsonlite::fromJSON(event)
    
      # static inputs
    met_networks  = "ALL"
    degree_filter = 1

    # extract observation data from JSON event 
    lon_obs  = data$longitude
    lat_obs  = data$latitude
    datetime = as.POSIXct(as.character(data$time), tz = "UTC")
    id       = as.character(data$id)

    # STEP 1: GET ELEVATION
    elev = rainOrSnowTools::get_elev(lon_obs, lat_obs)

    # STEP 2: GET ECO LEVEL 3
    eco_level3 = rainOrSnowTools:::get_eco_level3(lon_obs, lat_obs)

    # STEP 3: GET ECO LEVEL 4
    eco_level4 = rainOrSnowTools:::get_eco_level4(lon_obs, lat_obs)

    # STEP 4: GET STATE
    state = rainOrSnowTools:::get_state(lon_obs, lat_obs)

    # STEP 5: GET GPM PLP
    plp = rainOrSnowTools::get_imerg(datetime, lon_obs, lat_obs)

    # STEP 6: get meteo data
    # get_met_stations + get_met_data 
    meteo <- rainOrSnowTools::access_meteo(
        networks         = met_networks,
        datetime_utc_obs = datetime,
        lon_obs          = lon_obs,
        lat_obs          = lat_obs,
        deg_filter       = degree_filter
        )

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

    # convert processed data to JSON
    output_json = jsonlite::toJSON(
                    c(data,
                    as.list(dplyr::select(processed, -id))
                    )
                  )
                  
   return(output_json)
}

# Takes in the above event and creates a list of 3 datasets, the event added with meteo data, the meteo data validation, and the meteo data validation with humidity metrics
enrich_obs_data <- function(event) {

    # Convert JSON string to list
    data <- jsonlite::fromJSON(event)

    # static inputs
    met_networks  = "ALL"
    degree_filter = 1

    # extract observation data from JSON event 
    lon_obs  = data$longitude
    lat_obs  = data$latitude
    datetime = as.POSIXct(as.character(data$time), tz = "UTC")
    id       = as.character(data$id)

    # STEP 1: GET ELEVATION
    elev = rainOrSnowTools::get_elev(lon_obs, lat_obs)

    # STEP 2: GET ECO LEVEL 3
    eco_level3 = rainOrSnowTools:::get_eco_level3(lon_obs, lat_obs)

    # STEP 3: GET ECO LEVEL 4
    eco_level4 = rainOrSnowTools:::get_eco_level4(lon_obs, lat_obs)

    # STEP 4: GET STATE
    state = rainOrSnowTools:::get_state(lon_obs, lat_obs)

    # STEP 5: GET GPM PLP
    plp = rainOrSnowTools::get_imerg(datetime, lon_obs, lat_obs)

    # STEP 6: get meteo data
    # get_met_stations + get_met_data 
    meteo <- rainOrSnowTools::access_meteo(
        networks         = met_networks,
        datetime_utc_obs = datetime,
        lon_obs          = lon_obs,
        lat_obs          = lat_obs,
        deg_filter       = degree_filter
        )

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
    # STEP 9: Validate data
    ## validate_met_data ----
    # now validate station data
    # randomly select one station from meteo
    rando_station = meteo_subset[sample(nrow(meteo_subset), 1), ]
    rando_id = as.character(rando_station["id"])
    rando_metadata = rainOrSnowTools::gather_meta(rando_id)

    rando_station  %>% names()
    st_lon      = as.numeric(rando_metadata[1, "lon"])
    st_lat      = as.numeric(rando_metadata[1, "lat"])
    st_elev     = as.numeric(rando_metadata[1, "elev"])
    # st_datetime = as.POSIXct(as.character(rando_station[1, "datetime"]), tz = "UTC")

    # use these information to re-gather the meteo/etc
    st_meteo <- rainOrSnowTools::access_meteo(
                    networks         = met_networks,
                    datetime_utc_obs = datetime,
                    # datetime_utc_obs = st_datetime,
                    lon_obs          = st_lon,
                    lat_obs          = st_lat,
                    deg_filter       = degree_filter
                    )

    # take out the closest station data
    st_meteo <-
        st_meteo %>%
        dplyr::filter(id != rando_id)

    # STEP 10: Process and QA/QC meteo data
    # QC sampling meteo data
    st_meteo_qc <- rainOrSnowTools::qc_meteo(st_meteo)

    # subset meteo data to date ...?
    st_meteo_subset <- rainOrSnowTools:::select_meteo(st_meteo_qc, datetime)
    # st_meteo_subset <- select_meteo(st_meteo_qc, st_datetime)

    # get unique station IDs from "meteo_qc" dataframe
    st_stations_to_gather <- unique(st_meteo_qc$id)

    # get metadata for each station ID minus the randomly selected station
    st_metadata_minus_rando <- rainOrSnowTools::gather_meta(st_stations_to_gather)

    # STEP 11: Count validation stations
    # taily up number of statons in each network...? and then put into matrix
    st_station_counts = cbind(
        "hads_counts" = 
            st_metadata_minus_rando %>%
            dplyr::filter(network == "hads") %>%
            dplyr::tally() %>% 
            as.numeric(),
        "lcd_counts" = 
            st_metadata_minus_rando %>%
            dplyr::filter(network == "lcd") %>%
            dplyr::tally() %>%
            as.numeric(),
        "wcc_counts" = 
            st_metadata_minus_rando %>%
            dplyr::filter(network %in% c("snotel", "scan", "snotelt")) %>%
            dplyr::tally() %>%
            as.numeric()
            )

    # STEP 11: validate meteo data and store with station counts
    # validate meteo data and store with station counts
    validate_met <- cbind(
                    rainOrSnowTools::model_meteo(
                            id           = rando_id,
                            lon_obs      = st_lon,
                            lat_obs      = st_lat,
                            elevation    = st_elev,
                            datetime_utc = datetime,
                            #   datetime_utc = st_datetime,
                            meteo_df     = st_meteo_subset,
                            meta_df      = st_metadata_minus_rando
                            ),
                    st_station_counts,
                    dplyr::rename_with(
                        rando_station, 
                        ~paste0(.x, "_raw"), dplyr::everything()
                        )
                    )

    # STEP 12: Validate meteo data with humidity metrics
    # - now do the station data for stations in meteo that HAVE humidity metrics
    # - right now, rh and temp_dew
    # - this will likely be biased towards LCD and some WCC stations

    # get stations with humidity vars, if none,
    valid_data = tryCatch({
                meteo_qc %>%
                    dplyr::filter(!dplyr::if_any(c(temp_air, rh, temp_dew), is.na))
            }, error = function(e) {
                meteo_qc %>%
                    dplyr::filter(!dplyr::if_any(c(temp_air, rh), is.na))
            }, error = function(e){
                meteo_qc %>%
                    dplyr::filter(!dplyr::if_any(temp_air, is.na))
            })

    # if there are no stations with humidity metrics, then just use stations with temp_air
    if (nrow(valid_data) == 0) {
        valid_data = 
            meteo_qc %>% 
            dplyr::filter(!dplyr::if_any(c(temp_air, rh), is.na))
        } 

    # valid_data = if (nrow(valid_data) == 0) {
    #                 meteo_qc %>% 
    #                 dplyr::filter(!dplyr::if_any(c(temp_air, rh), is.na))
    #             } else {
    #                 valid_data = valid_data
    #             }

    # randomly select one station from meteo
    rando_station2  = valid_data[sample(nrow(valid_data), 1), ]
    rando_id2       = as.character(rando_station2["id"])
    rando_metadata2 = rainOrSnowTools::gather_meta(rando_id2)

    # get lon/lat/elev/datetime from randomly selected station
    st_lon2      = as.numeric(rando_metadata2[1, "lon"])
    st_lat2      = as.numeric(rando_metadata2[1, "lat"])
    st_elev2     = as.numeric(rando_metadata2[1, "elev"])
    st_datetime2 = as.POSIXct(as.character(rando_station2[1, "datetime"]), tz = "UTC")

    # use these information to re-gather the meteo/etc
    st_meteo2 <- rainOrSnowTools::access_meteo(
                        networks         = met_networks,
                        datetime_utc_obs = st_datetime2,
                        lon_obs          = st_lon2,
                        lat_obs          = st_lat2,
                        deg_filter       = degree_filter
                    )
    # take out the closest station data
    st_meteo_qc <-
        st_meteo_qc %>%
        filter(id != rando_id2)

    # STEP 13: Process and QA/QC meteo data
    # QC sampling meteo data
    st_meteo_qc_rando <- rainOrSnowTools::qc_meteo(st_meteo_qc)

    # subset meteo data to date ...?
    st_meteo_subset_rando <- rainOrSnowTools:::select_meteo(st_meteo_qc_rando, st_datetime2)

    # get unique station IDs from "meteo_qc" dataframe
    st_stations_to_gather_rando <- unique(st_meteo_qc_rando$id)

    st_metadata_minus_rando2 <- rainOrSnowTools::gather_meta(st_stations_to_gather_rando)

    # STEP 14: Count validation stations
    station_counts_rando = cbind(
        "hads_counts" = 
            st_metadata_minus_rando2 %>%
            dplyr::filter(network == "hads") %>%
            dplyr::tally() %>%
            as.numeric(),
        "lcd_counts" = 
            st_metadata_minus_rando2 %>%
            dplyr::filter(network == "lcd") %>%
            dplyr::tally() %>% 
            as.numeric(),
        "wcc_counts" =
            st_metadata_minus_rando2 %>%
            dplyr::filter(network %in% c("snotel", "scan", "snotelt")) %>%
            dplyr::tally() %>%
            as.numeric()
            )

    # STEP 15: validate meteo data and store with station counts
    validate_met_humidity <- cbind(
        rainOrSnowTools::model_meteo(
                    id           = rando_id2,
                    lon_obs      = st_lon2,
                    lat_obs      = st_lat2,
                    elevation    = st_elev2,
                    datetime_utc = st_datetime2,
                    meteo_df     = st_meteo_subset_rando,
                    meta_df      = st_metadata_minus_rando2
                    ),
        station_counts_rando,
        dplyr::rename_with(
            rando_station2, 
            ~paste0(.x, "_raw"), dplyr::everything()
            )
        )
        # # make outputs from list into dataframe format
        # # MRoS Data (private) ----
        # mros_data_private <- plyr::ldply(processed, dplyr::bind_rows)
        
        # # Met Data Stats -----
        # met_validation <- plyr::ldply(validate_met, dplyr::bind_rows)
        # met_validation_humidity <- plyr::ldply(validate_met_rando, dplyr::bind_rows)
        
        return(
            list(
            "mros_data_private"       = processed,
            "met_validation"          = validate_met,
            "met_validation_humidity" = validate_met_humidity
            )
        )
        
}

# event <- '{"id": "rec7vrLUoLMeZqfvr",
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

# met_obs <- add_met_to_obs(event)

# validate_met_obs <- function(event) {

#     # Convert JSON string to list
#     data <- jsonlite::fromJSON(event)

#     # static inputs
#     met_networks  = "ALL"
#     degree_filter = 1

#     # extract observation data from JSON event 
#     lon_obs  = data$longitude
#     lat_obs  = data$latitude
#     datetime = as.POSIXct(as.character(data$time), tz = "UTC")
#     id       = as.character(data$id)

#     # STEP 1: GET ELEVATION
#     elev = rainOrSnowTools::get_elev(lon_obs, lat_obs)

#     # STEP 2: GET ECO LEVEL 3
#     eco_level3 = rainOrSnowTools:::get_eco_level3(lon_obs, lat_obs)

#     # STEP 3: GET ECO LEVEL 4
#     eco_level4 = rainOrSnowTools:::get_eco_level4(lon_obs, lat_obs)

#     # STEP 4: GET STATE
#     state = rainOrSnowTools:::get_state(lon_obs, lat_obs)

#     # STEP 5: GET GPM PLP
#     plp = rainOrSnowTools::get_imerg(datetime, lon_obs, lat_obs)

#     # STEP 6: get meteo data
#     # get_met_stations + get_met_data 
#     meteo <- rainOrSnowTools::access_meteo(
#         networks         = met_networks,
#         datetime_utc_obs = datetime,
#         lon_obs          = lon_obs,
#         lat_obs          = lat_obs,
#         deg_filter       = degree_filter
#         )

#     # STEP 7: Process and QA/QC meteo data
#     # process_met_data 

#     # quality control meteo data
#     meteo_qc <- rainOrSnowTools::qc_meteo(meteo)

#     # subset meteo data to date ...? 
#     meteo_subset <- rainOrSnowTools:::select_meteo(meteo_qc, datetime)

#     # get unique station IDs from "meteo_qc" dataframe
#     stations_to_gather <- unique(meteo_qc$id)

#     # get metadata for each station ID
#     metadata <- rainOrSnowTools::gather_meta(stations_to_gather)\

#     # STEP 9: Validate data
#     ## validate_met_data ----
#     # now validate station data
#     # randomly select one station from meteo
#     rando_station = meteo_subset[sample(nrow(meteo_subset), 1), ]
#     rando_id = as.character(rando_station["id"])
#     rando_metadata = rainOrSnowTools::gather_meta(rando_id)

#     st_lon      = as.numeric(rando_metadata[1, "lon"])
#     st_lat      = as.numeric(rando_metadata[1, "lat"])
#     st_elev     = as.numeric(rando_metadata[1, "elev"])
#     # st_datetime = as.POSIXct(as.character(rando_station[1, "datetime"]), tz = "UTC")

#     # use these information to re-gather the meteo/etc
#     st_meteo <- rainOrSnowTools::access_meteo(
#                     networks         = met_networks,
#                     datetime_utc_obs = datetime,
#                     # datetime_utc_obs = st_datetime,
#                     lon_obs          = st_lon,
#                     lat_obs          = st_lat,
#                     deg_filter       = degree_filter
#                     )

#     # take out the closest station data
#     st_meteo <-
#         st_meteo %>%
#         dplyr::filter(id != rando_id)

#     # STEP 10: Process and QA/QC meteo data
#     # QC sampling meteo data
#     st_meteo_qc <- rainOrSnowTools::qc_meteo(st_meteo)

#     # subset meteo data to date ...?
#     st_meteo_subset <- rainOrSnowTools:::select_meteo(st_meteo_qc, datetime)
#     # st_meteo_subset <- select_meteo(st_meteo_qc, st_datetime)

#     # get unique station IDs from "meteo_qc" dataframe
#     st_stations_to_gather <- unique(st_meteo_qc$id)

#     # get metadata for each station ID minus the randomly selected station
#     st_metadata_minus_rando <- rainOrSnowTools::gather_meta(st_stations_to_gather)

#     # STEP 11: Count validation stations
#     # taily up number of statons in each network...? and then put into matrix
#     st_station_counts = cbind(
#         "hads_counts" = 
#             st_metadata_minus_rando %>%
#             dplyr::filter(network == "hads") %>%
#             dplyr::tally() %>% 
#             as.numeric(),
#         "lcd_counts" = 
#             st_metadata_minus_rando %>%
#             dplyr::filter(network == "lcd") %>%
#             dplyr::tally() %>%
#             as.numeric(),
#         "wcc_counts" = 
#             st_metadata_minus_rando %>%
#             dplyr::filter(network %in% c("snotel", "scan", "snotelt")) %>%
#             dplyr::tally() %>%
#             as.numeric()
#             )

#     # STEP 11: validate meteo data and store with station counts
#     # validate meteo data and store with station counts
#     validate_met <- cbind(
#                     rainOrSnowTools::model_meteo(
#                             id           = rando_id,
#                             lon_obs      = st_lon,
#                             lat_obs      = st_lat,
#                             elevation    = st_elev,
#                             datetime_utc = datetime,
#                             #   datetime_utc = st_datetime,
#                             meteo_df     = st_meteo_subset,
#                             meta_df      = st_metadata_minus_rando
#                             ),
#                     st_station_counts,
#                     dplyr::rename_with(
#                         rando_station, 
#                         ~paste0(.x, "_raw"), dplyr::everything()
#                         )
#                     )

#     return(validate_met)
# }

# -----------------------------------------
# -----------------------------------------