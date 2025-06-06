% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/meteo_qc.R
\name{qc_meteo}
\alias{qc_meteo}
\title{Functions for quality controlling meteorological data (qc_meteo)}
\usage{
qc_meteo(
  df,
  tair_limit_min = -30,
  tair_limit_max = 45,
  twet_limit_min = -40,
  twet_limit_max = 45,
  tdew_limit_min = -40,
  tdew_limit_max = 45,
  rh_limit_min = 10,
  rh_limit_max = 100,
  sd_thresh = 3
)
}
\arguments{
\item{df}{data.frame}

\item{tair_limit_min}{numeric}

\item{tair_limit_max}{numeric}

\item{twet_limit_min}{numeric}

\item{twet_limit_max}{numeric}

\item{tdew_limit_min}{numeric}

\item{tdew_limit_max}{numeric}

\item{rh_limit_min}{numeric}

\item{rh_limit_max}{numeric}

\item{sd_thresh}{numeric}
}
\value{
data.frame
}
\description{
Functions for quality controlling meteorological data (qc_meteo)
}
