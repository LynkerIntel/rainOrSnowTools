#' Function to gather metadata from meta_all using a vector of station ids
#'
#' @param stations Vector of station ids
#'
#' @return A dataframe of metadata filter to the station ids in 'stations'
#' @importFrom dplyr filter
#' @export
#'
#' @examples
#' stations = c('RRMI4', 'INLO2', 'JVDU1', '72526604751', 'RDKC2', 'TABC1', 'LSUA2', 'BAFO3', 'SOAC1', 'BNTC1')
#' gather_meta(stations)
gather_meta <- function(stations){
  # filter the metadata to only those in the station list
  dplyr::filter(all_meta, id %in% stations)
}
