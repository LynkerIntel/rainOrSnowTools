
#' Function to convert temperature in Fahrenheit to Celsius
#'
#' @param temp_F The temperature in degrees Fahrenheit
#'
#' @return The temperature in degrees Celsius
#' @export
#'
#' @examples
#' \dontrun{
#' tair_c <- f_to_c(temp_F = 32)
#' }
f_to_c <- function(temp_F){
  (temp_F - 32) * (5/9)
  }

#' Function to convert inches to millimeters
#'
#' @param ppt_in Input precipitation (or other depth quantity) in inches
#'
#' @return Output precipitation (or other depth quantity) in millimeters
#' @export
#'
#' @examples
#' \dontrun{
#' ppt_mm <- in_to_mm(ppt_in = 0.5)
#' }
in_to_mm <- function(ppt_in){
  ppt_in * 25.4
  }
