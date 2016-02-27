#' Specifies the host URL of the API to use
#'
#' A helper function to conveniently switch different APIs.
#'
#' @param instring Either "kobo", "kobohr", "ona", or a custom (full) URL.
#' @return A single string with the URL to use.
#' @note API URLs are made available for KoBo Toolbox ("kobo", \url{https://kc.kobotoolbox.org/api/v1/}), KoBo Humanitarian Response ("kobohr", \url{https://kc.humanitarianresponse.info/api/v1/}), and Ona ("ona", \url{https://ona.io/api/v1/}). For your own installation, or other installations using the same API but accessed at a different URL, enter the full URL.
#' @author Ananda Mahto
#' @examples
#' host("kobo")
#' host("https://ona.io/api/v1/") ## same as host("ona")
#' @export host
#'
host <- function(instring) {
  if (instring %in% c("kobo", "kobohr", "ona")) {
    switch(instring,
           kobo = "https://kc.kobotoolbox.org/api/v1/",
           kobohr = "https://kc.humanitarianresponse.info/api/v1/",
           ona = "https://ona.io/api/v1/")
  } else {
    instring
  }
}
NULL

#' Helper function for GET, depending on whether authentication is required
#'
#' Adds basic level authentication if provided.
#'
#' @param user string of length 1 or 2 with user details
#' @param URL The URL to be passed to curl
#' @note This function is not intended to be called directly. It is used in other functions.
#' @author Ananda Mahto
#'
get_me <- function(user, URL) {
  if (is.null(user)) {
    GET(URL)
  } else {
    u <- pwd_parse(user)
    GET(URL, authenticate(u$username, u$password))
  }
}
NULL

#' Helper function to parse a string to be used as a username/password combination
#'
#' Converts a string of length 1 or of length 2 into a list that can then be passed on to the \code{authenticate} function from the "httr" package.
#'
#' @param \dots A single string, character vetor, or list containing the username and password that should be used. If it is a single string, it should be in the form of "username:password".
#' @note This function is not intended to be called directly. It is used in other functions.
#'
#' @examples
#'
#' pwd_parse("username", "password")
#' pwd_parse("username:password")
#' pwd_parse(c("username", "password"))
#'
#' @author Ananda Mahto
#'
pwd_parse <- function(...) {
  upw <- unlist(list(...))
  nam <- c("username", "password")
  auth <- {
    if (length(upw) == 1) {
      unlist(strsplit(upw, ":", TRUE))
    } else {
      if (length(upw) > 2) {
        message("More than two values supplied. Using only first two values.")
        upw[1:2]
      } else {
        upw
      }
    }
  }
  setNames(as.list(auth), nam)
}
NULL

#' Lists the datasets available
#'
#' Lists the datasets available at the URL being accessed, possibly according to account.
#'
#' @param user Optional. A single string indicating the username and password ("username:password"), or a character vector or list, length 2, with the first value being the "username", and the second being the "password".
#' @param api The URL at which the API can be accessed. Defaults to "kobo", which loads the KoBo Toolbox API.
#'
#' @return A data.table containing details about the datasets available, including items like the "title", "id", and "url" of the datasets.
#'
#' @author Ananda Mahto
#'
#' @examples
#' kobo_datasets()
#'
#' @export kobo_datasets
#'
kobo_datasets <- function(user = NULL, api = "kobo") {
  URL <- sprintf(fmt = "%sdata.csv", host(api))
  x <- get_me(user, URL)
  fread(rawToChar(x$content))
}
NULL

#' Retrieve the number of submissions in a specified dataset
#'
#' Retrieves the number of submissions made to a specified dataset.
#'
#' @param formid The ID of the form to be accessed (as a character string).
#' @param user Optional. A single string indicating the username and password ("username:password"), or a character vector or list, length 2, with the first value being the "username", and the second being the "password".
#' @param api The URL at which the API can be accessed. Defaults to "kobo", which loads the KoBo Toolbox API.
#' @return A single number indicating the number of submissions received.
#' @author Ananda Mahto
#'
#' @examples
#' kobo_submission_count("15051")
#' kobo_submission_count("31511", api = "kobohr")
#'
#' @export kobo_submission_count
#'
kobo_submission_count <- function(formid, user = NULL, api = "kobo") {
  URL <- "%sstats/submissions/%s.csv?group=dummydatagroupingvar"
  URL <- sprintf(fmt = URL, host(api), formid)
  x <- get_me(user, URL)
  fread(rawToChar(x$content))$count
}
NULL


#' Retrieve the data from a specified dataset
#'
#' Retrieves the data submitted to a specified dataset.
#'
#' @param formid The ID of the form to be accessed (as a character string).
#' @param user Optional. A single string indicating the username and password ("username:password"), or a character vector or list, length 2, with the first value being the "username", and the second being the "password".
#' @param api The URL at which the API can be accessed. Defaults to "kobo", which loads the KoBo Toolbox API.
#' @param check Logical. Should the function first check to see whether the data is available offline.
#' @return A "data.table" with the full dataset. If data is already found on disk and the number of rows matches with the online datasets, the local copy would be used. The dataset would be named in the form of "data_formid".
#' @author Ananda Mahto
#'
#' @examples
#' kobo_data_downloader("15051")
#' kobo_data_downloader("31511", api = "kobohr")
#'
#' @export kobo_data_downloader
#'
kobo_data_downloader <- function(formid, user = NULL, api = "kobo", check = TRUE) {
  locfile <- sprintf(fmt = "data_%s", formid)

  if (isTRUE(check)) {
    if (exists(locfile)) {
      rows <- nrow(get(locfile))
      check <- kobo_submission_count(formid, user, api)
      if (rows == check) {
        message("Number of rows in local and remote file match.")
        redownload = FALSE
      } else {
        message(sprintf(fmt = "Local file found with %d rows. Remote file contains %d rows.", rows, check))
        redownload = TRUE
      }
    } else {
      message("No local dataset found.")
      redownload = TRUE
    }
  } else {
    redownload = TRUE
  }

  if (isTRUE(redownload)) {
    message("Downloading remote file.")
    URL <- sprintf(fmt = '%sdata/%s.csv', host(api), formid)

    x <- get_me(user, URL)

    out <- suppressWarnings(fread(rawToChar(x$content)))
    assign(locfile, out, envir = .GlobalEnv)
    out
  } else {
    message("Using local file.")
    get(locfile)
  }
}
NULL
