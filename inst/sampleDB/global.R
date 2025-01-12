library(tools)
library(yaml)

message('Loading global environment...')

# Global Variables
Global <- list(
  DefaultStateSearchTerm = "Active",
  DefaultStatusSearchTerm = "In Use"
)

database <- Sys.getenv("SDB_PATH")

# Session independent declarations go here

dbUpdateEvent <- reactivePoll(1000 * 5, NULL,
    function() file.mtime(Sys.getenv("SDB_PATH")),
    function() {
      list.data <- list(
          plate_name = sampleDB::CheckTable("matrix_plate")$plate_name,
          box_name = sampleDB::CheckTable("box")$box_name,
          rdt_bag_name = sampleDB::CheckTable("bag")$bag_name,
          paper_bag_name = sampleDB::CheckTable("bag")$bag_name,
          study = sampleDB::CheckTable("study") %>%
            pull(var = id, name = short_code),
          specimen_type = sampleDB::CheckTable("specimen_type")$label,
          location = sampleDB::CheckTable("location")$location_name,
          subject = sampleDB::CheckTable(database = database, "study_subject") %>%
            pull(var = study_id, name = subject),
          status = sampleDB::CheckTable(database = database, "status")$name,
          state = sampleDB::CheckTable(database = database, "state")$name
        )

      return(list.data)
    }
  )




