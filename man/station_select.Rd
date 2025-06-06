% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/meteo_access.R
\name{station_select}
\alias{station_select}
\title{Gather the metadata for meteorological stations}
\usage{
station_select(network, lon_obs, lat_obs, deg_filter, dist_thresh_m)
}
\arguments{
\item{network}{network to gather stations from (HADS, LCD, or WCC)}

\item{lon_obs}{Longitude in decimal degrees}

\item{lat_obs}{Latitude in decimal degrees}

\item{deg_filter}{Number of degrees surrounding the point location to which the station search should be limited}

\item{dist_thresh_m}{Distance (in meters) that a station must be within to be considered}
}
\value{
Dataframe of station metadata
}
\description{
Gather the metadata for meteorological stations
}
