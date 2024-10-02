#!/usr/bin/env Rscript

# Load required libraries

library(argparse)

# Set up argument parser
parser <- ArgumentParser(description="Run ForestForesight sync and prediction on a monthly basis")
parser$add_argument("-s", "--shapefile", type="character", required=TRUE,
                    help="Path to the input shapefile")
parser$add_argument("-d", "--ff_folder", type="character", required=TRUE,
                    help="Path to the ForestForesight data folder")
parser$add_argument("-o", "--output_folder", type="character", required=TRUE,
                    help="Path to the folder where predictions and models will be saved")
parser$add_argument("-l", "--log_file", type="character", default="ff_monthly_log.txt",
                    help="Path to the log file (default: ff_monthly_log.txt)")

# Parse arguments with error handling

args <- parser$parse_args()
cat(paste("using", args$shapefile,"to process predictions using data from",args$ff_folder,"and saving them to",args$output_folder,"\n"))
if(args$ff_folder==""){stop("ff-folder should be given")}
library(ForestForesight)
# Function to log messages
log_message <- function(message) {
  timestamp <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  cat(paste(timestamp, message, "\n"), file=args$log_file, append=TRUE)
}
shapefile=args$shapefile
ff_folder=args$ff_folder
output_folder=args$output_folder
# Main execution function
run_monthly_process <- function() {
  tryCatch({
    # Get the first day of the current month
    current_date <- floor_date(Sys.Date(), "month")

    log_message(paste0("Starting monthly process for date: ", as.character(current_date)))

    # Load the shapefile
    shape <- project(vect(shapefile),"epsg:4326")
    print(getinfo(shape))
    # Run ff_sync
    log_message("Running ff_sync...")
    ff_sync(
      ff_folder = ff_folder,
      identifier = shape,
      download_data = TRUE,
      download_model = FALSE,
      download_predictions = FALSE,
      verbose = TRUE
    )

    # Run ff_run
    log_message("Running ff_run...")
    prediction <- ff_run(
      shape = shape,
      prediction_dates = as.character(current_date),
      ff_folder = args$ff_folder,
      train_dates = ForestForesight::daterange(current_date - months(18), current_date - months(6)),
      save_path = file.path(args$output_folder, paste0("model_", format(current_date, "%Y%m%d"), ".model")),
      save_path_predictions = file.path(args$output_folder, paste0("prediction_", format(current_date, "%Y%m%d"), ".tif")),
      accuracy_csv = file.path(args$output_folder, "accuracy_log.csv"),
      verbose = TRUE
    )

    log_message("Monthly process completed successfully.")
  }, error = function(e) {
    log_message(paste("Error occurred:", e$message))
  })
}

# Run the process
run_monthly_process()
