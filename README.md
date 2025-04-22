
<!-- README.md is generated from README.Rmd. Please edit that file -->

# rainOrSnowTools

<!-- badges: start -->

[![R-CMD-check](https://github.com/SnowHydrology/rainOrSnowTools/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/SnowHydrology/rainOrSnowTools/actions/workflows/R-CMD-check.yaml)

<!-- badges: end -->

<img src="https://www.dri.edu/wp-content/uploads/badge.png" align="right" width="150"/>

The goal of the `rainOrSnowTools` R package is to support analysis for
the [**Mountain Rain or Snow**](https://www.rainorsnow.org/) **citizen
science project**.

### `rainOrSnowTools` provides:

------------------------------------------------------------------------

1.  Access to meteorological data from the
    [HADS](https://hads.ncep.noaa.gov/),
    [LCD](https://www.ncei.noaa.gov/products/land-based-station/local-climatological-data),
    and [WCC](https://www.nrcs.usda.gov/wps/portal/wcc/home/) networks.
2.  Modeled meteorological data (air/dew point/wet bulb temperature and
    relative humidity) for an observation point.
3.  [GPM IMERG probability of liquid
    precipitation](https://gpm.nasa.gov/data/imerg) (pLP) data for an
    observation point.
4.  Geographical data (elevation, state, and ecoregion 3/4) for an
    observation point.
5.  QA/QC of processed observation data.

------------------------------------------------------------------------

:point_right: **The processed data are available on our [public-facing
dashboard](https://rainorsnowmaps.com/)** :point_left:

You can learn more about how to use the data on the dashboard’s [User
Guide tab](https://rainorsnowmaps.com/obs).

## Installation and Loading

You can install `rainOrSnowTools` with:

``` r
# install.packages("devtools")
devtools::install_github("LynkerIntel/rainOrSnowTools")
```

Load in the `rainOrSnowTools` library:

``` r
library(rainOrSnowTools)
```

<br>

### Package Functions

Each observation is geotagged with a datetime, location (latitude,
longitude) and phase observation.

In this example, we will use the following sample:
`datetime: 2025-04-10 12:30:00 UTC`,`lat = 40`,`lon = -105`,
`phase = "Snow"`

#### Tagging an observation with ancillary data:

##### Geography-related:

*Only need to provide a lat/lon*

| **Function**     | **Description**                                             |
|------------------|-------------------------------------------------------------|
| `get_elev`       | Elevation in meters, derived from the USGS 3DEP 10m product |
| `get_eco_level3` | EPA Ecoregion Level 3                                       |
| `get_eco_level4` | EPA Ecoregion Level 4                                       |
| `get_state`      | U.S. State                                                  |

``` r
# Elevation data in meters:
elev <- rainOrSnowTools::get_elev(lon_obs = lon,
                                  lat_obs = lat)
# [1] 1590.199
```

##### Meteorological-related:

*Need to provide datetime and lat/lon*

| **Function**  | **Description**                                                                                                                                                                                                                                                |
|---------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `get_imerg`   | GPM IMERG Probability of Liquid Precipitation value (closer to 0 = likely snow, closer to 100 = likely rain)                                                                                                                                                   |
| `model_meteo` | This final function uses data collected from helper functions to model met variables for an observation point. Will only provide modeled data for points with \>= 5 station data. Helper functions = `access_meteo`, `qc_meteo`, `select_meteo`, `gather_meta` |

- `access_meteo` = Access data (+/- 1 hour) from the met network of
  choice (`HADS`, `LCD`, `WCC`, or `ALL`). Required variables include
  `datetime`, `lat`, `lon`, `deg_filter` (search radius)
- `qc_meteo` = QC the met data collected using standard thresholds
- `select_meteo` = Final selection of the met data from the network(s)
  of choice, filtering data to grab the closest in time
- `gather_meta` = Gathers the metadata associated for each station from
  `select_meteo`

``` r
# Get GPM IMERG probability of liquid precipitation:
plp <- rainOrSnowTools::get_imerg(datetime_utc    = datetime,
                                  lon_obs         = lon,
                                  lat_obs         = lat,
                                  product_version = 'GPM_3IMERGHHL.07')

# [1] 13
# This values agrees with the Snow phase report
```

*Note that the GPM IMERG algorithm has deprecated the version 6 as of
late 2024, [see
here](https://gpm.nasa.gov/resources/documents/imerg-v07-release-notes)*

------------------------------------------------------------------------

###### Example workflow:

Get modeled meteorological variables, harnessing data from the HADS,
LCD, and WCC met networks.

``` r
# Define the static vars
met_networks = "ALL"
degree_filter = 1

meteo <- rainOrSnowTools::access_meteo(networks         = met_networks,
                                       datetime_utc_obs = datetime,
                                       lon_obs          = lon,
                                       lat_obs          = lat,
                                       deg_filter       = degree_filter)

# Output of 387 observations of 7 variables
# head(meteo)
#      id            datetime temp_air rh temp_dew temp_wet ppt
# 1 AENC2 2025-04-10 11:56:00 1.111111 57       NA       NA  NA
# 2 AENC2 2025-04-10 12:56:00 2.222222 57       NA       NA  NA
# 3 BAWC2 2025-04-10 12:22:00 2.777778 33       NA       NA  NA
# 4 BAWC2 2025-04-10 13:22:00 4.444444 31       NA       NA  NA
# 5 BCFC2 2025-04-10 11:42:00 1.666667 45       NA       NA  NA
# 6 BCFC2 2025-04-10 12:42:00 1.111111 47       NA       NA  NA
 
# QC the meteo data
meteo_qc <- rainOrSnowTools::qc_meteo(meteo)
## All data pass QC

# Subset the data to select data points closest in time, and average the measured value
meteo_subset <- rainOrSnowTools:::select_meteo(meteo_qc, datetime)

# Get unique station IDs from the "meteo_qc" dataframe
stations_to_gather <- unique(meteo_qc$id)

# Get metadata for each station ID
metadata <- rainOrSnowTools::gather_meta(stations_to_gather)

# Get modeled meteorological variables, harnessing data from the HADS, LCD, and WCC met networks
met_vars <- rainOrSnowTools::model_meteo(id           = "example",
                                         lon_obs      = lon,
                                         lat_obs      = lat,
                                         elevation    = elev,
                                         datetime_utc = datetime,
                                         meteo_df     = meteo_subset,
                                         meta_df      = metadata)
```

    #> # A tibble: 1 × 37
    #>   id      temp_air_idw_lapse_const temp_air_idw_lapse_var temp_air_nearest_sit…¹
    #>   <chr>                      <dbl>                  <dbl>                  <dbl>
    #> 1 example                     1.25                   1.02                 -0.686
    #> # ℹ abbreviated name: ¹​temp_air_nearest_site_const
    #> # ℹ 33 more variables: temp_air_nearest_site_var <dbl>, temp_air_avg_obs <dbl>,
    #> #   temp_air_min_obs <dbl>, temp_air_max_obs <dbl>, temp_air_lapse_var <dbl>,
    #> #   temp_air_lapse_var_r2 <dbl>, temp_air_lapse_var_pval <dbl>,
    #> #   temp_air_n_stations <int>, temp_air_avg_time_gap <dbl>,
    #> #   temp_air_avg_dist <dbl>, temp_air_nearest_id <chr>,
    #> #   temp_air_nearest_elev <dbl>, temp_air_nearest_dist <dbl>, …
