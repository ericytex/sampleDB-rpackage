#' Upload EPPIcenter Wetlab Samples to the SampleDB database
#'
#' `UploadSamples()` can be used to upload wetlab samples to the sampleDB database.
#' Currently the type of wetlab samples supported is only `micronix`. <!---cryovial`, `rdt` and `paper` sample uploads will appear in the next version.-->
#'
#' @param sample_type A string specifying the type of samples that are being uploaded Options include: `micronix`, `cryovial`, `rdt` and `paper`
#' @param upload_data A dataframe of SampleDB Upload data.\cr
#' Required `upload_data` columns are:\cr
#' `well_position`: the row and column of the sample in the storage housing
#' `label`: the sample's label or barcode
#' `study_subject_id`: the participant id of for the subject in the cohort (ie study)
#' `study_short_code`: the code of the study
#' `specimen_type`: the sample type
#' `collection_date`: (optional) the date the sample was first collected from the cohort participant
#'
#' #' **upload data example without collection_date**
#'
#' | well_position | label | study_subject_id | specimen_type | study_short_code |
#' | ------------- | ----- | ---------------- | ------------- | ---------------- |
#' | A0            | xxx1  | subject_1        | PLASMA        | KAM06            |
#' | A1            | xxx2  | subject_2        | PLASMA        | KAM06            |
#'
#' **upload data example with collection_date**
#'
#' | well_position | label | study_subject_id | specimen_type | study_short_code | collection_data |
#' | ------------- | ----- | ---------------- | ------------- | ---------------- | --------------- |
#' | A0            | xxx1  | subject_1        | PLASMA        | KAM06            | 2022-04-11      |
#' | A1            | xxx2  | subject_2        | PLASMA        | KAM06            | 2022-04-11      |
#'
#' @param container_name A string specifying the name of the container the samples are in. Names must be unique within each sample type.
#' @param container_barcode A string specifying the barcode for the container the samples are in. Container barcodes are optional. Barcodes must be unique within each sample type.
#' @param freezer_address A list specifying the freezer address used to store samples. \cr
#' Required items in the freezer_address list are `location_name`, `level_I` and `level_II`.
#' If the freezer_address type is `minus eighty` then `level_I` and `level_II` items specify the rack and position, respecively.
#' If the freezer_address type is `minus twenty` then `level_I` and `level_II` items specify the shelf and basket, respecively.
#' @examples
#' \dontrun{
#' UploadSamples(sample_type = "micronix",
#'               upload_data = tibble(well_position = c("A0"),
#'                                    label = c("XXX 1"),
#'                                    study_subject_id = c("1"),
#'                                    specimen_type = c("PLASMA"),
#'                                    study_short_code = c("KAM06"),
#'                                    collection_date = c("2021-04-10")),
#'                container_name = "test_container",
#'                freezer_address = list(location_name = "TBD",
#'                                       level_I = "TBD",
#'                                       level_II = "seve's working basket"))
#' }
#' @import dplyr
#' @import RSQLite
#' @import emojifont
#' @import readr
#' @import tidyr
#' @import lubridate
#' @export

UploadSamples <- function(sample_type, upload_data, container_name, container_barcode = NULL, freezer_address){

  # locate the database and connect to it
  database <- Sys.getenv("SDB_PATH")
  conn <-  RSQLite::dbConnect(RSQLite::SQLite(), database)

  # save a copy of the upload data as a csv
  .SaveUploadCSV(upload_data, container_name)

  # if there is no collection date, for standardization create a collection date column of NAs
  if(!"collection_date" %in% names(upload_data)){
    upload_data$collection_date <- NA
  }
  
  # if there is no comment, for standardization create a collection date column of NAs
  if(!"comment" %in% names(upload_data)){
    upload_data$comment <- NA
  }


  # remove empty strings, replace with NA
  upload_data <- upload_data %>% 
      mutate_if(is.character, list(~na_if(.,"")))

  # perform upload checks
  .UploadChecks(sample_type = sample_type, input = input, database = database,
                freezer_address = freezer_address, container_name = container_name,
                container_barcode = container_barcode, upload_data = upload_data)

  # upload data
  .UploadSamples(upload_data = upload_data, sample_type = sample_type,
                 conn = conn, container_name = container_name, freezer_address = freezer_address,
                 container_barcode = container_barcode)

  return_message <- paste("Upload Successful!\nPlate", container_name, "with", nrow(upload_data), "sample(s) were added to freezer address:", paste(unlist(freezer_address, use.names=F), collapse = ", "), "\n")

  #close connection
  tryCatch(
    RSQLite::dbDisconnect(conn),
    warning=function(w){})

  message(return_message)
  return(return_message)
}

.UploadChecks <- function(sample_type, input, database, freezer_address, container_name, container_barcode, upload_data){

  message("Performing upload checks...")

  stopifnot("Error: Empty file detected." = nrow(upload_data) > 0)

  # check storage type
  stopifnot("Error: Storage type is not valid." = sampleDB:::.CheckSampleStorageType(sample_type = sample_type))

  # check logistical colnames
  stopifnot("Error: Malformed colnames. Valid colnames are:" = sampleDB:::.CheckFormattedLogisticalColnames(formatted_upload_file = upload_data))

  # check logistical colnames
  stopifnot("Error: Malformed colnames. Valid colnames are:" = sampleDB:::.CheckFormattedMetaDataColnames(formatted_upload_file = upload_data))

  # check freezer address exists
  stopifnot("Error: Freezer address does not exist" = sampleDB:::.CheckFreezerAddress(freezer_address = freezer_address, database = database))

  # check that specimen type exists
  stopifnot("Error: Specimen type(s) does not exist" = sampleDB:::.CheckUploadSpecimenTypes(database = database, formatted_upload_file = upload_data))

  # check that study codes exists
  stopifnot("Error: Study Short Code(s) does not exist" = sampleDB:::.CheckUploadStudyShortCodes(database = database, formatted_upload_file = upload_data))

  # check collection date format is correct
  #create a vector from the collection date column and remove all NAs in the vector the perform this check
  collection_dates <- upload_data$"collection_date"[!is.na(upload_data$"collection_date")]
  if(length(collection_dates) != 0){
    stopifnot("Error: Collection date is not in Year, Month, Day format" = sampleDB:::.CheckUploadDateFormat(database = database, formatted_upload_file = upload_data))
  }

  # check that micronix containerbarcodes are unique
  out <- sampleDB:::.CheckBarcodeIsntInDB(database = database, formatted_upload_file = upload_data)
  stopifnot("Error: Barcode Unique Constraint" = out$out1)
  if(length(out$out2) > 0){
    print(out$out2)
  }

  out <- sampleDB:::.CheckWellPositionIsValid(database = database, formatted_upload_file = upload_data)
  if (!out$out1) {
    message(paste0(x <- names(out$out2),":", paste0(out$out2[x], sep='\n')))
    stopifnot("Error: Well Validation Constraint" = out$out1)
  }

  # check that micronix container barcodes are not duplicated
  out <- sampleDB:::.CheckBarcodeArentRepeated(database = database, formatted_upload_file = upload_data)
  stopifnot("Barcodes in upload data are duplicated" = out$out1)
  if(length(out$out2) > 0){
    print(out$out2)
  }

  # check plate name
  # stopifnot("Error: Container name is not unique" = sampleDB:::.CheckUploadContainerNameDuplication(database = database, plate_name = container_name, only_active = TRUE))

  # check plate barcode
  stopifnot("Error: Container barcode is not unique" = sampleDB:::.CheckUploadContainerBarcodeDuplication(plate_barcode = container_barcode, database = database))

  # check that uploaded samples are not going to take the well of an active sample
  if (sample_type == "micronix") {
    tmp <- sampleDB::CheckTable(database = database, "storage_container") %>%
      select(status_id, id) %>%
      filter(status_id == 1) %>%
      inner_join(sampleDB::CheckTable(database = database, "matrix_tube"), by = c("id" = "id")) %>%
      inner_join(sampleDB::CheckTable(database = database, "matrix_plate"), by = c("plate_id" = "id")) %>%
      filter(plate_name %in% container_name) %>%
      select(plate_id, well_position, status_id) %>%
      inner_join(upload_data, by = c("well_position" = "well_position"))

    stopifnot("Uploading sample to well location that already has an active sample" = (nrow(tmp) == 0))
  }
}


.UploadSamples <- function(upload_data, sample_type, conn, container_name, container_barcode, freezer_address){
  RSQLite::dbBegin(conn)

  for(i in 1:nrow(upload_data)){

    #1. get upload item's metadata
    eval.specimen_type <- upload_data[i, ]$"specimen_type" %>% as.character()
    eval.study_code <- upload_data[i, ]$"study_short_code" %>% as.character()
    eval.subject <- upload_data[i, ]$"study_subject_id" %>% as.character()
    eval.barcode <- upload_data[i,]$"label" %>% as.character()
    eval.well_position <- upload_data[i,]$"well_position"
    eval.comment <- upload_data[i,]$"comment" %>% as.character()
    if(is.na(upload_data[i, ]$"collection_date")){
      eval.collection_date <- as.double(as.Date(NA))
    }else{
      eval.collection_date <- ymd(upload_data[i, ]$"collection_date")
      eval.collection_date <- as.double(as.Date(paste(year(eval.collection_date), month(eval.collection_date), day(eval.collection_date), sep = "-")))
    }

    #get a database id for a upload item's specimen_type and study
    eval.specimen_type_id <- filter(CheckTableTx(conn = conn, "specimen_type"), label == eval.specimen_type)$id
    eval.study_id <- filter(CheckTableTx(conn = conn, "study"), short_code == eval.study_code)$id

    #2a. check if this upload item's participant (subject+study combination) exists in the database
    tmp_table.study_subject <- inner_join(CheckTableTx(conn = conn, "study_subject")[, c("subject", "study_id")],
                                          tibble(subject = eval.subject, study_id = eval.study_id),
                                          by = c("subject", "study_id"))

    #if this upload item's participant exists in the database, then get the necessary "study_subject" id
    if(nrow(tmp_table.study_subject) > 0){
      eval.study_subject_id <- filter(CheckTableTx(conn = conn, "study_subject"), subject == eval.subject, study_id == eval.study_id)$id

      #3a. check if this sample exists (subject+study+specimen_type) in the database
      tmp_table.specimen <- inner_join(CheckTableTx(conn = conn, "specimen")[,c("study_subject_id", "specimen_type_id", "collection_date")],
                                       tibble(study_subject_id = eval.study_subject_id, specimen_type_id = eval.specimen_type_id, collection_date = eval.collection_date),
                                       by = c("study_subject_id", "specimen_type_id", "collection_date"))

      #if this upload item's sample exists in the database, then get the necessary "specimen" id
      if(nrow(tmp_table.specimen) > 0){

        #how specimen id is retrieved depends on whether the collection date is NA or !is NA
        if(is.na(eval.collection_date)){
          eval.specimen_id <- filter(CheckTableTx(conn = conn, "specimen"),
                                     study_subject_id == eval.study_subject_id,
                                     specimen_type_id == eval.specimen_type_id,
                                     is.na(eval.collection_date))$id

        }else{
          eval.specimen_id <- filter(CheckTableTx(conn = conn, "specimen"),
                                     study_subject_id == eval.study_subject_id,
                                     specimen_type_id == eval.specimen_type_id,
                                     collection_date == eval.collection_date)$id
        }
      }else{

        #3b. if this participant (study_subject) exists in the database but sample (specimen) does not, then create a new "specimen"
        AddToTable("specimen",
                             list(created = lubridate::now() %>% as.character(),
                                  last_updated = lubridate::now() %>% as.character(),
                                  study_subject_id = eval.study_subject_id,
                                  specimen_type_id = eval.specimen_type_id,
                                  collection_date = eval.collection_date),
                             conn = conn) %>% suppressWarnings()

        #retrieve newly made specimen id
        eval.specimen_id <- tail(CheckTableTx(conn = conn, "specimen"), 1)$id
      }
    }else{
      #2b. if this upload item's participant (combination of subject+study) does not exist in the database then create a new study_subject entry in the database
      AddToTable("study_subject",
                           list(created = lubridate::now() %>% as.character(),
                                last_updated = lubridate::now() %>% as.character(),
                                subject = eval.subject,
                                study_id = eval.study_id),
                           conn = conn) %>% suppressWarnings()

      # get the newly created study_subject id
      eval.study_subject_id <- tail(CheckTableTx(conn = conn, "study_subject"), 1)$id

      #3b. create a new sample (study+subject+specimen_type) (ie specimen) in the database
      AddToTable("specimen",
                           list(created = lubridate::now() %>% as.character(),
                                last_updated = lubridate::now() %>% as.character(),
                                study_subject_id = eval.study_subject_id,
                                specimen_type_id = eval.specimen_type_id,
                                collection_date = eval.collection_date),
                           conn = conn) %>% suppressWarnings()

      # get the newly created specimen id
      eval.specimen_id <- tail(CheckTableTx(conn = conn, "specimen"), 1)$id
    }

    # sample automatically in use
    eval.status_id <- filter(sampleDB::CheckTableTx(conn = conn, "status"), name %in% "In Use")$id
    eval.state_id <- filter(sampleDB::CheckTableTx(conn = conn, "state"), name %in% "Active")$id

    #4. create the new item's storage container to the database using the item's sample id

    AddToTable("storage_container",
                         list(created = lubridate::now() %>% as.character(),
                              last_updated = lubridate::now() %>% as.character(),
                              type = sample_type,
                              specimen_id = eval.specimen_id,
                              status_id = eval.status_id, # In Use
                              state_id = eval.state_id,
                              comment = eval.comment),
                         conn = conn) %>% suppressWarnings()

    #5. get just item's storage container id and use it as the primary key in the matrix tube table
    eval.id <- tail(CheckTableTx(conn = conn, "storage_container"), 1)$id

    # 6. Create new sample housing (if it does not alread exist) and upload samples into housing
    if(sample_type == "micronix"){
      # create a new housing (if it does not already exist)
      if(!container_name %in% CheckTableTx(conn = conn, "matrix_plate")$plate_name){
        eval.plate_id <- sampleDB:::.UploadMicronixPlate(conn = conn, container_name = container_name, container_barcode = container_barcode, freezer_address = freezer_address)
      }else{
        eval.plate_id <- filter(CheckTableTx(conn = conn, "matrix_plate"), plate_name == container_name)$id
      }

      # 7. upload micronix sample
      AddToTable(table_name = "matrix_tube",
                           info_list = list(id = eval.id,
                                            plate_id = eval.plate_id,
                                            well_position = eval.well_position,
                                            barcode = eval.barcode),
                           conn = conn) %>% suppressWarnings()
    }
  }

  RSQLite::dbCommit(conn)

  #close connection
  tryCatch(
    RSQLite::dbDisconnect(conn),
    warning=function(w){
      message(w)
    })

}

# .UploadMicronixPlate <- function(database, container_name, container_barcode, freezer_address, conn){
#   eval.location_id <- filter(CheckTable(database = database, "location"), location_name == freezer_address$location, level_I == freezer_address$level_I, level_II == freezer_address$level_II)$id
#   if(is.null(container_barcode)){
#     container_barcode <- NA
#   }
#   else if(container_barcode == ""){
#     container_barcode <- NA
#   }
#   else{
#     container_barcode <- container_barcode
#   }
#   # print(container_barcode)
#   AddToTable(database = database,
#                        "matrix_plate",
#                        list(created = lubridate::now() %>% as.character(),
#                             last_updated = lubridate::now() %>% as.character(),
#                             location_id = eval.location_id,
#                             plate_name = container_name,
#                             plate_barcode = container_barcode),
#                        conn = conn) %>% suppressWarnings()
#   eval.plate_id <- tail(sampleDB::CheckTable(database = database, "matrix_plate"), 1)$id
#
#   return(eval.plate_id)
#
# }

.SaveUploadCSV <- function(upload_data, container_name){
  path <- normalizePath(
      file.path(dirname(Sys.getenv("SDB_PATH")), "upload_files"))
  
  if(dir.exists(path)) {
    write.csv(upload_data,
      suppressWarnings(
        normalizePath(
          file.path(path,
                 paste0(gsub("[T:]", "_",
                    lubridate::format_ISO8601(lubridate::now())),
                 "_", container_name, "_",
                 "UPLOAD.csv")))),
          row.names = FALSE)
  }
}
