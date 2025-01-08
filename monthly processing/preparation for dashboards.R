library(ForestForesight)
library(zip)
library(terra)
library(future)
library(furrr)
library(dplyr)

# Define explicit directory paths
working_directory <- "D:/ff-dev/dashboard"
forest_foresight_folder <- get_variable("FF_FOLDER")
arcgis_python_location <- "'C:/Program Files/ArcGIS/Pro/bin/Python/envs/arcgispro-py3/python.exe'"
python_script_location <- 'C:data/git/ForestForesight-dev/scripts_jonas/tilepackager/map_tile_package.py'
processing_date <- format(lubridate::floor_date(Sys.Date(), "month"), "%Y-%m-01")

# Setup parallel processing with explicit core count
available_cores <- parallel::detectCores(logical = FALSE)
parallel_cores <- available_cores %/% 2
plan(multisession, workers = parallel_cores)

# Create directories with explicit names
polygon_directory <- file.path(working_directory, "polygons")
dir.create(polygon_directory, recursive = TRUE, showWarnings = FALSE)

# Load countries dataset
countries_dataset <- as.data.frame(vect(get(data("countries"))))


setwd(working_directory)

# Define the processing function for each country
process_country <- function(country_row) {
  country_iso_code <- country_row$iso3
  country_full_name <- country_row$name

  processing_result <- list(
    error = NULL,
    raster = NULL
  )

  tryCatch({
    ff_cat(paste("Processing", country_full_name), verbose = TRUE)

    raster_file_path <- file.path(Sys.getenv("FF_FOLDER"), "predictions", country_iso_code,
                                  paste0(country_iso_code, "_", processing_date, ".tif"))

    if(file.exists(raster_file_path)) {
      # Load and project raster
      country_raster <- rast(raster_file_path)
      projected_raster <- project(country_raster, "epsg:3857")

      # Process risk levels before reclassification
      medium_risk_result <- ff_polygonize(
        projected_raster,
        threshold = "medium",
        output_file = file.path(polygon_directory, paste0(country_iso_code, "_medium.shp")),
        verbose = TRUE,
        calculate_max_count = TRUE
      )

      if(has_value(medium_risk_result$polygons)) {
        max_polygon_count <- medium_risk_result$max_count

        # Save medium risk polygons
        medium_risk_result$polygons$country <- country_iso_code
        writeVector(medium_risk_result$polygons,
                    file.path(polygon_directory, paste0(country_iso_code, "_medium.shp")),
                    overwrite = TRUE)

        high_risk_result <- ff_polygonize(
          projected_raster,
          threshold = "high",
          output_file = file.path(polygon_directory, paste0(country_iso_code, "_high.shp")),
          verbose = TRUE,
          max_polygons = max_polygon_count,
          contain_polygons = medium_risk_result$polygons
        )

        if(has_value(high_risk_result$polygons)) {
          high_risk_result$polygons$country <- country_iso_code
          writeVector(high_risk_result$polygons,
                      file.path(polygon_directory, paste0(country_iso_code, "_high.shp")),
                      overwrite = TRUE)

          very_high_risk_result <- ff_polygonize(
            projected_raster,
            threshold = "very high",
            output_file = file.path(polygon_directory, paste0(country_iso_code, "_very_high.shp")),
            verbose = TRUE,
            max_polygons = max_polygon_count,
            contain_polygons = high_risk_result$polygons
          )

          if(has_value(very_high_risk_result$polygons)) {
            very_high_risk_result$polygons$country <- country_iso_code
            writeVector(very_high_risk_result$polygons,
                        file.path(polygon_directory, paste0(country_iso_code, "_very_high.shp")),
                        overwrite = TRUE)
          }
        }
      }

      # Reclassify values after polygonization

      # Return success status and processed raster
      return(list(
        status = "success",
        countryiso = country_iso_code,
        files_created = TRUE,
        raster = projected_raster
      ))
    }
  },
  error = function(error_message) {
    return(list(
      status = "error",
      countryiso = country_iso_code,
      error = conditionMessage(error_message),
      timestamp = Sys.time(),
      raster = NULL
    ))
  })
}

# Process countries in parallel
ff_cat(sprintf("Processing countries in parallel using %d cores", parallel_cores))
processing_results <- future_map(
  1:nrow(countries_dataset),
  ~process_country(countries_dataset[.x,]),
  .options = furrr_options(seed = TRUE)
)

# Extract and combine rasters
ff_cat("Combining all rasters")
country_raster_list <- lapply(processing_results, function(x) x$raster)
filtered_raster_list <- Filter(Negate(is.null), country_raster_list)
unnamed_raster_list <- unname(filtered_raster_list)
merged_raster <- do.call(terra::merge, unnamed_raster_list)

# Write combined raster
ff_cat("Writing combined raster")
writeRaster(merged_raster,
            filename = file.path(working_directory, paste0("combined_raster_", processing_date, ".tif")),
            overwrite = TRUE)

# Process errors
error_results <- Filter(function(x) x$status == "error", processing_results)
if(length(error_results) > 0) {
  ff_cat("The following countries had errors:")
  for(error_result in error_results) {
    ff_cat(sprintf("\n%s:\n", error_result$countryiso))
    print(error_result$error)
  }
}

# Combine all the individual files
ff_cat("Combining all risk files")

# Function to safely read and combine vector files
combine_risk_files <- function(risk_level) {
  shapefile_pattern <- paste0("_", risk_level, ".shp$")
  shapefile_list <- list.files(polygon_directory, pattern = shapefile_pattern, full.names = TRUE)
  if(risk_level=="high"){
    print(length(shapefile_list))
    shapefile_list <- shapefile_list[-grep("very", shapefile_list)]
    print(length(shapefile_list))
  }
  if(length(shapefile_list) > 0) {
    vector_list <- lapply(shapefile_list, function(shapefile) {
      tryCatch({
        vect(shapefile)
      }, error = function(e) NULL)
    })
    valid_vectors <- Filter(Negate(is.null), vector_list)

    if(length(valid_vectors) > 0) {
      return(do.call(rbind, valid_vectors))
    }
  }
  return(NULL)
}

# Combine results for each risk level
combined_medium_risk <- combine_risk_files("medium")
combined_high_risk <- combine_risk_files("high")
combined_very_high_risk <- combine_risk_files("very_high")

# Create output directory
output_directory <- file.path(working_directory, "combined_risk_areas")
dir.create(output_directory, showWarnings = FALSE)

# Write combined files
ff_cat("Writing combined risk shapefiles")
if(!is.null(combined_medium_risk)) {
  writeVector(combined_medium_risk, file.path(output_directory, "combined_medium_risk.shp"), overwrite = TRUE)
}
if(!is.null(combined_high_risk)) {
  writeVector(combined_high_risk, file.path(output_directory, "combined_high_risk.shp"), overwrite = TRUE)
}
if(!is.null(combined_very_high_risk)) {
  writeVector(combined_very_high_risk, file.path(output_directory, "combined_very_high_risk.shp"), overwrite = TRUE)
}

# Create zip file
ff_cat("Creating zip archive")
zip_file_path <- file.path(working_directory, paste0("combined_risk_areas_", processing_date, ".zip"))
files_to_archive <- list.files(output_directory, full.names = TRUE)

zip::zip(
  zipfile = zip_file_path,
  files = files_to_archive,
  mode = "cherry-pick"
)
raster_file_path <- list.files(file.path(Sys.getenv("FF_FOLDER"), "predictions"),recursive=T, pattern=processing_date,full.names = T)
load_and_convert <- function(raster){
  raster=rast(raster)
  #raster <- project(rast(raster),"epsg:3857")
  raster[raster<0.5]=NA
  return(raster)
}
all_rasters <- sapply(raster_file_path,function(x) load_and_convert(x))
all_rasters <- unname(all_rasters)
merged_raster <- do.call(terra::merge,all_rasters)
raster <- project(merged_raster,"epsg:3857",filename="2024-12-01_global_predictions.tif")


ff_cat("Processing complete")
ff_cat(paste("Output zip file:", zip_file_path))
