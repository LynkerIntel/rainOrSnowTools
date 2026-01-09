
<!-- README.md is generated from README.Rmd. Please edit that file -->

# rainOrSnowTools

<!-- badges: start -->

[![R-CMD-check](https://github.com/SnowHydrology/rainOrSnowTools/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/SnowHydrology/rainOrSnowTools/actions/workflows/R-CMD-check.yaml)

<!-- badges: end -->

<img src="https://www.dri.edu/wp-content/uploads/badge.png" align="right" width="150"/>

The goal of the `rainOrSnowTools` R package is to support analysis for
the [**Mountain Rain or Snow**](https://www.rainorsnow.org/) **citizen
science project**.

:cloud_with_snow::cloud_with_rain::point_right: **The processed data are
available on our [public-facing
dashboard](https://rainorsnowmaps.com/)**
:point_left::cloud_with_rain::cloud_with_snow:

You can learn more about how to use the data on the dashboard’s [User
Guide tab](https://rainorsnowmaps.com/obs).

------------------------------------------------------------------------

### `rainOrSnowTools` provides:

1.  Access to meteorological data from the
    [HADS](https://hads.ncep.noaa.gov/),
    [LCD](https://www.ncei.noaa.gov/products/land-based-station/local-climatological-data),
    [WCC](https://www.nrcs.usda.gov/wps/portal/wcc/home/), and
    [MADIS](https://madis-data.ncep.noaa.gov/) networks.
2.  Modeled meteorological data (air/dew point/wet bulb temperature and
    relative humidity) for an observation point.
3.  [GPM IMERG probability of liquid
    precipitation](https://gpm.nasa.gov/data/imerg) (PLP) data for an
    observation point.
4.  Geographical data (elevation, state, and Ecoregion 3/4) for an
    observation point.
5.  QC of processed observation data.

------------------------------------------------------------------------

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

## Package Functions

Each observation is geotagged with a datetime, location (latitude,
longitude) and phase observation.

In this example, we will use the following sample:
`datetime: 2025-04-10 12:30:00 UTC`,`lat = 40`,`lon = -105`,
`phase = "Snow"`

#### Tagging an observation with ancillary data:

#### Geography-related:

*Need to provide a lat/lon*

| **Function** | **Description** |
|----|----|
| `get_elev` | Elevation in meters, derived from the USGS 3DEP 10m product |
| `get_eco_level3` | EPA Ecoregion Level 3 |
| `get_eco_level4` | EPA Ecoregion Level 4 |
| `get_state` | U.S. State |

``` r
# Elevation data in meters:
elev <- rainOrSnowTools::get_elev(lon_obs = lon,
                                  lat_obs = lat)
# [1] 1590.199
```

#### Meteorology-related:

*Need to provide datetime and lat/lon*

| **Function** | **Description** |
|----|----|
| `get_imerg` | GPM IMERG Probability of Liquid Precipitation value (closer to 0 = likely snow, closer to 100 = likely rain) |
| `model_meteo` | This final function uses data collected from helper functions to model met variables for an observation point. Will only provide modeled data for points with \>= 5 station data. Helper functions = `access_meteo`, `qc_meteo`, `select_meteo`, `gather_meta` |

- `access_meteo` = Access data (+/- 1 hour) from the met network of
  choice (`HADS`, `LCD`, `WCC`, `MADIS`, or `ALL`). Required variables
  include `datetime`, `lat`, `lon`, `deg_filter` (search radius)
  - *Note that LCD stations are no longer an available network after
    August 2025*
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
                                  product_version = 'GPM_3IMERGHHL.07') # this is the default version

# [1] 2
# This values agrees with the Snow phase report
```

*Note that the GPM IMERG algorithm has deprecated the version 6 as of
late 2024, [see
here](https://gpm.nasa.gov/resources/documents/imerg-v07-release-notes)*

------------------------------------------------------------------------

##### Example workflow:

Get modeled meteorological variables, harnessing data from the HADS,
WCC, and MADIS met networks.

``` r
# Define the static vars
met_networks = "ALL" # Call the HADS, WCC, and MADIS stations
degree_filter = 1 # 1º radius

meteo <- rainOrSnowTools::access_meteo(networks         = met_networks,
                                       datetime_utc_obs = datetime,
                                       lon_obs          = lon,
                                       lat_obs          = lat,
                                       deg_filter       = degree_filter)
#> Warning in file(file, "rt"): cannot open URL
#> 'https://www.ncei.noaa.gov/access/services/data/v1?dataset=local-climatological-data&stations=72438504828,72220012832,72539614815,72218604892,99999963898,72743604863,72635594871,72541614864,72437503893,72638414817,72743404870,99999954810,72324013882,72541404886,72436313803,72538794899,72090300441,72054300167,72535404806,72648094853,72225013829,72424013807,72533014827,72034054818,72041500140,72073600265,72438814829,72635094860,72628494836,72744014858,72539404839,72436553896,72438453842,72057500173,72438093819,A0735900240,72635794815,72438754807,74780703821,72438614835,72096100336,72423513810,72423093821,72636404883,72638594894,72540804881,74421494852,72743094850,72533694895,72019854813,72636014840,72639404874,72533594833,72320093801,72435653866,72535014848,72234354826,72538354827,72437303868,72037154850,72638714850,99999900430,72026654809,72067400249,72405853818,72540404847,72060100193,72521014895,72430314813,72216013869,72316013870,72540554816,72639094849,72319093846,72
#> [... truncated]

# List of Observations ("met") and Metadata ("metadata")

met <- meteo[["met"]]

# QC the meteo data
meteo_qc <- rainOrSnowTools::qc_meteo(met)
## All data pass QC

# Subset the data to select data points closest in time, and average the measured value
meteo_subset <- rainOrSnowTools:::select_meteo(meteo_qc, datetime)

# Get metadata for each station ID
metadata <- meteo$metadata %>%
          dplyr::filter(id %in% meteo_subset$id)
```

``` r
# `metadata` can get the number of data points from each network

#>      hads_counts wcc_counts madis_counts
#>       43         22          357

# `meteo_subset` can get the number of data points for each met variable

#>    rh temp_air temp_dew temp_wet
#>   360      404      333        0
```

``` r
# Finally, get modeled meteorological variables
met_vars <- rainOrSnowTools::model_meteo(id           = "example",
                                         lon_obs      = lon,
                                         lat_obs      = lat,
                                         elevation    = elev,
                                         datetime_utc = datetime,
                                         meteo_df     = meteo_subset,
                                         meta_df      = metadata)
```

``` r
# Output of 37 variables, does not include the QC flags

# Temperature units = ºC and RH unit = %
dplyr::tibble(met_vars)
#> # A tibble: 1 × 37
#>   id      temp_air_idw_lapse_const temp_air_idw_lapse_var temp_air_nearest_sit…¹
#>   <chr>                      <dbl>                  <dbl>                  <dbl>
#> 1 example                     5.50                   5.31                   7.43
#> # ℹ abbreviated name: ¹​temp_air_nearest_site_const
#> # ℹ 33 more variables: temp_air_nearest_site_var <dbl>, temp_air_avg_obs <dbl>,
#> #   temp_air_min_obs <dbl>, temp_air_max_obs <dbl>, temp_air_lapse_var <dbl>,
#> #   temp_air_lapse_var_r2 <dbl>, temp_air_lapse_var_pval <dbl>,
#> #   temp_air_n_stations <int>, temp_air_avg_time_gap <dbl>,
#> #   temp_air_avg_dist <dbl>, temp_air_nearest_id <chr>,
#> #   temp_air_nearest_elev <dbl>, temp_air_nearest_dist <dbl>, …
```

*Data Citations:*

Kantor, Diana; Casey, Nancy W.; Menne, Matthew J.; Buddenberg, Andrew.
2023. Local Climatological Data (LCD), Version 1. NOAA National Centers
for Environmental Information.
<https://www.ncei.noaa.gov/access/metadata/landing-page/bin/iso?id=gov.noaa.ncdc:C01689>.
\[before 29 Aug 2025\]

NOAA National Centers for Environmental Prediction. 2006.
Hydrometeorological Automated Data System (HADS). NOAA National Centers
for Environmental Information.

NOAA. (n.d.). MADIS Meteorological Surface Dataset. Meteorological
Assimilation Data Ingest System (MADIS). <https://madis.ncep.noaa.gov/>

NRCS. (n.d.). Snow and Climate Monitoring rRports and Maps. U.S.
Department of Agriculture.
<https://www.nrcs.usda.gov/wps/portal/wcc/home/>
