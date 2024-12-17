library(ForestForesight)
library(zip)
library(terra)
library(future)
library(furrr)
library(dplyr)

workdir <- "C:/data/dashboard_data/"
ff_folder <- "C:/data/storage/"
arcpy_location <- "'C:/Program Files/ArcGIS/Pro/bin/Python/envs/arcgispro-py3/python.exe'"
script_location <- 'C:data/git/ForestForesight-dev/scripts_jonas/tilepackager/map_tile_package.py'
proc_date <- format(lubridate::floor_date(Sys.Date(), "month"), "%Y-%m-01")

# Setup parallel processing
n_cores <- parallel::detectCores(logical = FALSE) %/% 2
plan(multisession, workers = n_cores)

# Create directories
poly_dir <- file.path(workdir, "polygons")
dir.create(poly_dir, recursive = TRUE, showWarnings = FALSE)

# Load countries and convert to data.frame for parallel processing
countries_df <- as.data.frame(vect(get(data("countries"))))
countries_df$geometry <- NULL  # Remove geometry column

setwd(workdir)

# Define the processing function for each country
process_country <- function(country_row) {
  countryiso <- country_row$iso3
  country_name <- country_row$name

  result <- list(
    error = NULL
  )

  tryCatch({
    ff_cat(paste("Processing", country_name), verbose = TRUE)

    rast_path <- file.path(Sys.getenv("FF_FOLDER"), "predictions", countryiso,
                           paste0(countryiso, "_", proc_date, ".tif"))

    if(file.exists(rast_path)) {
      # Process risk levels and save files directly
      medium_risk <- ff_polygonize(
        rast_path,  # Pass the path instead of the raster object
        threshold = "medium",
        output_file = file.path(poly_dir, paste0(countryiso, "_medium.shp")),
        verbose = TRUE,
        calculate_max_count = TRUE
      )

      if(has_value(medium_risk$polygons)) {
        max_count <- medium_risk$max_count

        # Save medium risk result directly to file
        medium_risk$polygons$country <- countryiso
        writeVector(medium_risk$polygons,
                    file.path(poly_dir, paste0(countryiso, "_medium.shp")),
                    overwrite = TRUE)

        high_risk <- ff_polygonize(
          rast_path,
          threshold = "high",
          output_file = file.path(poly_dir, paste0(countryiso, "_high.shp")),
          verbose = TRUE,
          max_polygons = max_count,
          contain_polygons = medium_risk$polygons
        )

        if(has_value(high_risk$polygons)) {
          high_risk$polygons$country <- countryiso
          writeVector(high_risk$polygons,
                      file.path(poly_dir, paste0(countryiso, "_high.shp")),
                      overwrite = TRUE)

          very_high_risk <- ff_polygonize(
            rast_path,
            threshold = "very high",
            output_file = file.path(poly_dir, paste0(countryiso, "_very_high.shp")),
            verbose = TRUE,
            max_polygons = max_count,
            contain_polygons = high_risk$polygons
          )

          if(has_value(very_high_risk$polygons)) {
            very_high_risk$polygons$country <- countryiso
            writeVector(very_high_risk$polygons,
                        file.path(poly_dir, paste0(countryiso, "_very_high.shp")),
                        overwrite = TRUE)
          }
        }
      }

      # Return success status
      return(list(
        status = "success",
        countryiso = countryiso,
        files_created = TRUE
      ))
    }
  },
  error = function(e) {
    return(list(
      status = "error",
      countryiso = countryiso,
      error = conditionMessage(e),
      timestamp = Sys.time()
    ))
  })
}

# Process countries in parallel
ff_cat(sprintf("Processing countries in parallel using %d cores", n_cores))
results <- future_map(
  1:nrow(countries_df),
  ~process_country(countries_df[.x,]),
  .options = furrr_options(seed = TRUE)
)

# Process errors
errors <- Filter(function(x) x$status == "error", results)
if(length(errors) > 0) {
  ff_cat("The following countries had errors:")
  for(error in errors) {
    ff_cat(sprintf("\n%s:\n", error$countryiso))
    print(error$error)
  }
}

# Now combine all the individual files
ff_cat("Combining all risk files")

# Function to safely read and combine vector files
combine_risk_files <- function(risk_level) {
  pattern <- paste0("_", risk_level, ".shp$")
  files <- list.files(poly_dir, pattern = pattern, full.names = TRUE)
  if(risk_level=="high"){
    print(length(files))
    files=files[-grep("very",files)]
    print(length(files))
  }
  if(length(files) > 0) {
    vectors <- lapply(files, function(f) {
      tryCatch({
        vect(f)
      }, error = function(e) NULL)
    })
    vectors <- Filter(Negate(is.null), vectors)

    if(length(vectors) > 0) {
      return(do.call(rbind, vectors))
    }
  }
  return(NULL)
}

# Combine results
all_medium_risk <- combine_risk_files("medium")
all_high_risk <- combine_risk_files("high")
all_very_high_risk <- combine_risk_files("very_high")

# Create output directory
output_dir <- file.path(workdir, "combined_risk_areas")
dir.create(output_dir, showWarnings = FALSE)

# Write combined files
ff_cat("Writing combined risk shapefiles")
if(!is.null(all_medium_risk)) {
  writeVector(all_medium_risk, file.path(output_dir, "combined_medium_risk.shp"), overwrite = TRUE)
}
if(!is.null(all_high_risk)) {
  writeVector(all_high_risk, file.path(output_dir, "combined_high_risk.shp"), overwrite = TRUE)
}
if(!is.null(all_very_high_risk)) {
  writeVector(all_very_high_risk, file.path(output_dir, "combined_very_high_risk.shp"), overwrite = TRUE)
}

# Create zip file
ff_cat("Creating zip archive")
zip_file <- file.path(workdir, paste0("combined_risk_areas_", proc_date, ".zip"))
files_to_zip <- list.files(output_dir, full.names = TRUE)

zip::zip(
  zipfile = zip_file,
  files = files_to_zip,
  mode = "cherry-pick"
)

ff_cat("Processing complete")
ff_cat(paste("Output zip file:", zip_file))
