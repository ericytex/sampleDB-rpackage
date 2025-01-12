#' Delete Empty Wetlab Containers in the EPPIcenter SampleDB database
#' @import dplyr
#' @export

DeleteEmptyContainer <- function(type, container_name, conn){

  stopifnot("Sample Type is not valid" = type %in% c("micronix", "cryovial", "rdt", "paper"))

  if(type == "micronix"){
    id.container <- filter(sampleDB::CheckTableTx(conn = conn, "matrix_plate"), plate_name == container_name)$id
    if (is_empty(id.container)) {
      warning("Attempt to delete matrix plate that does not exist (was it deleted after deleting all of it's samples?)")
    }
    if(filter(sampleDB::CheckTableTx(conn = conn, "matrix_tube"), plate_id %in% id.container) %>% nrow() == 0){
      sampleDB::DeleteFromTable(conn = conn,
                                table_name = "matrix_plate",
                                id = as.character(id.container))
      return_message <- paste0("Successfully Deleted Container: \n", container_name)
    }else{
      return_message <- "Error Container is not empty"
    }
  }
  else if(type == "cryovial"){
    id.container <- filter(sampleDB::CheckTableTx(conn = conn, "box"), box_name == container_name)$id
    if (is_empty(id.container)) {
      warning("Attempt to delete box that does not exist (was it deleted after deleting all of it's samples?)")
    }
    if(filter(sampleDB::CheckTableTx(conn = conn, "tube"), plate_id %in% id.container) %>% nrow() == 0){
      sampleDB::DeleteFromTable(conn = conn,
                                table_name = "box",
                                id = as.character(id.container))
      return_message <- paste0("Successfully Deleted Container: \n", container_name)
    }else{
      return_message <- "Error Container is not empty"
    }
  }
  else if(type == "rdt"){
    id.container <- filter(sampleDB::CheckTableTx(conn = conn, "bag"), bag_name == container_name)$id
    if (is_empty(id.container)) {
      warning("Attempt to delete bag that does not exist (was it deleted after deleting all of it's samples?)")
    }
    if(filter(sampleDB::CheckTableTx("rdt"), bag_id %in% id.container) %>% nrow() == 0){
      sampleDB::DeleteFromTable(conn = conn,
                                table_name = "bag",
                                id = as.character(id.container))
      return_message <- paste0("Successfully Deleted Container: \n", container_name)
    }else{
      return_message <- "Error Container is not empty"
    }
  }
  else{
    id.container <- filter(sampleDB::CheckTableTx(conn = conn, "bag"), bag_name == container_name)$id
    if (is_empty(id.container)) {
      warning("Attempt to delete bag that does not exist (was it deleted after deleting all of it's samples?)")
    }
    if(filter(sampleDB::CheckTableTx("paper"), bag_id %in% id.container) %>% nrow() == 0){
      sampleDB::DeleteFromTable(conn = conn,
                                table_name = "bag",
                                id = as.character(id.container))
      return_message <- paste0("Successfully Deleted Container: \n", container_name)
    }else{
      return_message <- "Error Container is not empty"
    }
  }

  message(return_message)
  return(return_message)
}
