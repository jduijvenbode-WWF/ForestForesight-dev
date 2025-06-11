
# Streamlined Fire Alerts Processing Pipeline
# Direct path from NASA data to final raster products with 10-day batching

library(httr)
library(readr)
library(dplyr)
library(sf)
library(terra)
library(stringr)
library(glue)
library(lubridate)


# Configuration
MAP_KEY <- "193b52280657e5b21c20bdd911205bf9"
AREA_COORDS <- "-120,-30,180,30"
TEMPLATE_PATH <- "/Users/temp/Zillah Analytics/WWF/ff_folder/preprocessed/groundtruth"
OUTPUT_PATH <- "./test"
SENSORS <- c( "VIIRS_SNPP_NRT", "VIIRS_NOAA20_NRT", "VIIRS_NOAA21_NRT", "MODIS_NRT")


# Main streamlined function
process_fire_alerts <- function(target_month = NULL, overwrite = FALSE) {
  
  # Setup
  month <- if(is.null(target_month)) floor_date(Sys.Date(), "month") else as.Date(paste0(target_month, "-01"))
  download_month <- month - months(1)  # Previous month for complete data
  dir.create(OUTPUT_PATH, recursive = TRUE, showWarnings = FALSE)
  
  cat("Processing fire alerts for", format(month, "%Y-%m"), "\n")
  
  # Step 1: Download and combine all fire data with 10-day batching
  cat("Downloading fire data in 10-day batches...\n")
  
  # Generate 10-day intervals
  month_start <- download_month
  month_end <- month_start + months(1) - days(1)
  date_chunks <- list()
  current_date <- month_start
  while(current_date <= month_end) {
    chunk_end <- min(current_date + days(9), month_end)
    date_chunks[[length(date_chunks) + 1]] <- c(current_date, chunk_end)
    current_date <- chunk_end + days(1)
  }
  
  # Download all batches for all sensors
  all_fire_data <- bind_rows(lapply(SENSORS, function(sensor) {
    bind_rows(lapply(date_chunks, function(chunk) {
      chunk_start <- chunk[1]
      days_range <- as.integer(chunk[2] - chunk[1] + 1)
      url <- glue("https://firms.modaps.eosdis.nasa.gov/api/area/csv/{MAP_KEY}/{sensor}/{AREA_COORDS}/{days_range}/{chunk_start}")
      
      tryCatch({
        response <- GET(url)
        if(status_code(response) == 200) {
          content_text <- content(response, "text", encoding = "UTF-8")
          if(str_count(content_text, "\n") > 1) {
            read_csv(I(content_text), show_col_types = FALSE) %>%
              select(latitude, longitude) %>%
              mutate(satellite = str_extract(sensor, "MODIS|VIIRS"))
          }
        }
      }, error = function(e) NULL)
    }))
  })) %>%
    filter(!is.na(latitude), !is.na(longitude),
           between(latitude, -90, 90), between(longitude, -180, 180)) %>%
    st_as_sf(coords = c("longitude", "latitude"), crs = 4326)
  
  if(nrow(all_fire_data) == 0) {
    cat("No fire data found\n")
    return(NULL)
  }
  
  cat("Found", nrow(all_fire_data), "fire points\n")
  
  # Step 2: Process each tile directly to final products
  cat("Processing tiles...\n")
  template_tiles <- list.files(TEMPLATE_PATH, pattern = "2021-01-01_groundtruth1m.tif", 
                               full.names = TRUE, recursive = TRUE)
  
  lapply(template_tiles, function(tile_path) {
    start_time <- Sys.time()
    tile_name <- str_extract(basename(tile_path), "\\d{2}[NS]_\\d{3}[EW]")
    template <- rast(tile_path)
    
    date_str <- format(month, "%Y-%m-%d")
    tile_dir <- file.path(OUTPUT_PATH, tile_name)
    dir.create(tile_dir, recursive = TRUE, showWarnings = FALSE)
    
    out_file_1m <- file.path(tile_dir, glue("{tile_name}_{date_str}_firealerts1m.tif"))
    out_file_3m <- file.path(tile_dir, glue("{tile_name}_{date_str}_firealerts3m.tif"))
    out_file_6m <- file.path(tile_dir, glue("{tile_name}_{date_str}_firealerts6m.tif"))
    out_file_6to12m <- file.path(tile_dir, glue("{tile_name}_{date_str}_firealerts6to12m.tif"))
    out_file_trend <- file.path(tile_dir, glue("{tile_name}_{date_str}_yearlyfiretrend.tif"))
    
    # Step 1: Clip and rasterize fire points only if 1-month file is missing
    if  (!file.exists(out_file_1m) || overwrite){
    bbox_poly <- st_as_sfc(st_bbox(template))
    tile_fires <- st_intersection(all_fire_data, st_transform(bbox_poly, 4326)) %>%
      st_transform(crs(template))
    
    if(nrow(tile_fires) == 0) {
      cat("No fires in tile:", tile_name, "\n")
      return(NULL)
    }
    
    fire_raster <- rasterize(vect(tile_fires), template, fun = "length", background = 0)
    n_satellites <- length(unique(tile_fires$satellite))
    avg_alerts <- fire_raster / n_satellites
    
    writeRaster(avg_alerts, out_file_1m, overwrite = TRUE)
    } else {
      avg_alerts <- rast(out_file_1m)  # Load existing raster
    }
    
    # Step 2: Use the 1-month raster to create derived products
    existing_files <- list.files(tile_dir, pattern = "firealerts1m\\.tif$", full.names = TRUE)
    existing_files <- sort(existing_files)
    
    if(length(existing_files) >= 3 && (!file.exists(out_file_3m) || overwrite)) {
      avg_3m <- mean(rast(tail(existing_files, 3)), na.rm = TRUE)
      writeRaster(avg_3m, out_file_3m, overwrite = TRUE)
      cat("Saved 3-month average\n")
    } else if (file.exists(out_file_3m)) {
      cat("Skipped 3-month average (exists)\n")
    }
    
    if(length(existing_files) >= 6 && (!file.exists(out_file_6m) || overwrite)) {
      avg_6m <- mean(rast(tail(existing_files, 6)), na.rm = TRUE)
      writeRaster(avg_6m, out_file_6m, overwrite = TRUE)
      cat("Saved 6-month average\n")
    } else if (file.exists(out_file_6m)) {
      cat("Skipped 6-month average (exists)\n")
    }
    
    if(length(existing_files) >= 12 && (!file.exists(out_file_6to12m) || overwrite)) {
      files_6to12 <- existing_files[(length(existing_files)-11):(length(existing_files)-5)]
      avg_6to12m <- mean(rast(files_6to12), na.rm = TRUE)
      writeRaster(avg_6to12m, out_file_6to12m, overwrite = TRUE)
      cat("Saved 6–12 month average\n")
    } else if (file.exists(out_file_6to12m)) {
      cat("Skipped 6–12 month average (exists)\n")
    }
    
    # Step 5: Yearly trend
    last_year_date <- format(month - years(1), "%Y-%m-%d")
    last_year_3m_file <- file.path(tile_dir, glue("{tile_name}_{last_year_date}_firealerts3m.tif"))
    
    if(file.exists(out_file_3m) && file.exists(last_year_3m_file) &&
       (!file.exists(out_file_trend) || overwrite)) {
      current_3m <- rast(out_file_3m)
      last_year_3m <- rast(last_year_3m_file)
      yearly_trend <- current_3m - last_year_3m
      writeRaster(yearly_trend, out_file_trend, overwrite = TRUE)
      cat("Saved yearly trend\n")
    } else if (file.exists(out_file_trend)) {
      cat("Skipped yearly trend (exists)\n")
    }
    
    elapsed <- round(difftime(Sys.time(), start_time, units = "secs"), 2)
    cat("Processed tile:", tile_name, "- time:", elapsed, "seconds\n\n")
    return(tile_name)
  })
  
  
  
  cat("Pipeline complete! Output in:", OUTPUT_PATH, "\n")
  return(OUTPUT_PATH)
}

# Usage
# process_fire_alerts()              # Current month
# process_fire_alerts("2024-01")     # Specific month