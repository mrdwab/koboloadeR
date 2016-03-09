#' @import httr
NULL

#' @import data.table
NULL

#' @import bit64
NULL

#' @import readr
NULL

f_csv <- function(x) setDT(read_csv(content(x, "raw")))[]

