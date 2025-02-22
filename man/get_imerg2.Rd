% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/citsci_preprocess.R
\name{get_imerg2}
\alias{get_imerg2}
\title{Download GPM IMERG data (deprecated)
Old version of get_imerg function that uses dplyr dataframes to generate the GPM IMERG product URLs}
\usage{
get_imerg2(datetime_utc, lon_obs, lat_obs, verbose = FALSE)
}
\arguments{
\item{datetime_utc}{Observation time in UTC format YYYY-MM-DD HH:MM:SS. Default is NULL.}

\item{lon_obs}{numeric, Longitude in decimal degrees. Default is NULL.}

\item{lat_obs}{numeric, Latitude in decimal degrees. Default is NULL.}

\item{verbose}{logical, whether to print messages or not}
}
\value{
a dataframe of GPM data for each observation
}
\description{
Download GPM IMERG data (deprecated)
Old version of get_imerg function that uses dplyr dataframes to generate the GPM IMERG product URLs
}
\examples{
\dontrun{
datetime_utc = as.POSIXct("2023-01-01 16:00:00", tz = "UTC")
lon = -105
lat = 40
gpm <- get_imerg2(datetime_utc, lon_obs = lon, lat_obs = lat)
}
}
