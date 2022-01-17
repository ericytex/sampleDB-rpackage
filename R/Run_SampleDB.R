#' @import dplyr
#' @import shiny
#' @import DT
#' @import shinyFeedback
#' @import markdown
#' @import lubridate
#' @export

Run_SampleDB <- function(){
  # this needs to be set by the computer it's running on
  # reticulate::use_virtualenv("/home/mmurphy/.pyenv/versions/r-reticulate")
  db_file_loc <- normalizePath("~/Workspace/sampleDB-rpackage/files/sqlite_database/19-Oct-21.sample_db.sqlite")
  options("sampledblib.db.location" = sprintf("sqlite:///%s", db_file_loc))
  options("sampledblib.fm.dateformat" = "%d-%b-%Y")
  sampledblib.r::initialize_sampledb()

  shiny::runApp(system.file('sampleDB', package='sampleDB'))
}
