library(dplyr)
library(sampleDB)
library(shinyFeedback)
library(shiny)
library(readr)
library(markdown)
library(lubridate)
library(emojifont)
library(DT)
library(purrr)

#load helper files
for(server_helper in list.files(path = "server_helpers", full.names = T, recursive = T)){
  source(server_helper, local = TRUE)
}

function(input, output, session) {
  
    # Back up database when app is fired up... supplementary files such as the backup generator are stored in /extdata
    # for (i in system("bash /sampleDB_backup_generator.sh", intern = TRUE)) message(i)
    Backup_SampleDB(checksum = TRUE) 

    # Set path to .sqlite database
    database <- Sys.getenv("SDB_PATH")
    backups <- list.files(file.path(dirname(database), "backups"))
    if (length(backups) > 10) {
      oldest_backup <- file.path(dirname(database), "backups", head(backups, 1))
      message(paste0("Removing oldest backup: ", oldest_backup))
      file.remove(file.path(dirname(database), "backups", head(backups, 1)))
    }

    # --------- Upload Samples -------------

    # Upload Micronix Samples
    MicronixUpload(session, output, input, database)
    
    # Upload Cryo Samples
    # CryoUpload(session, output, input, database)

    # Upload RDT Samples
    # RDTUpload(session, output, input, database)

    # Upload Paper Samples
    # PaperUpload(session, output, input, database)
    
    # -------- Search Samples -------------
    
    SearchWetlabSamples(session, input, database, output)
    
    # -------- Move Samples -------------

    MoveWetlabSamples(session, input, database, output)

    # -------- Edit Containers --------
    
    EditWetlabContainers(session, input, database, output)
    
    # -------- Archive and Delete Samples --------
    
    DelArchSamples(session, input, database, output)

    # -------- Delete Empty Container --------
    
    # DeleteEmptyWetlabContainers(session, input, database, output)
    
    # -------- Update References ---------------
    
    # Update Freezers
    UpdateLabFreezers(session, input, output, database)
    
    # Update Specimen Types
    UpdateSpecimenTypes(session, input, output, database)
    
    # Update EPPIcenter Lab Studies
    UpdateLabStudies(session, input, output, database)

    # Configuration panel
    AppPreferencesPanel(session, input, output, database)

    # --------------- About ------------
}
