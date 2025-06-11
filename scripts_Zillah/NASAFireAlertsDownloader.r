# Required packages
library(httr)
library(readr)
library(dplyr)
library(sf)
library(lubridate)

# Utility to generate 10-day intervals
generate_10_day_intervals <- function(start_date, end_date) {
  start <- as.Date(start_date)
  end <- as.Date(end_date)
  dates <- list()
  while (start <= end) {
    chunk_end <- min(start + days(9), end)
    dates[[length(dates) + 1]] <- c(start, chunk_end)
    start <- chunk_end + days(1)
  }
  return(dates)
}


# NASA FIRMS Downloader
NASAFireAlertsDownloader <- function(map_key) {
  base_url <- "https://firms.modaps.eosdis.nasa.gov/api"
  
  list(
    download_range = function(start_date, end_date, area_coords = NULL, country = NULL,
                               sensors = c("VIIRS_SNPP_NRT", "VIIRS_NOAA20_NRT", "MODIS_NRT")) {
      start_date <- as.Date(start_date)
      end_date <- as.Date(end_date)
      month_starts <- seq(as.Date(floor_date(start_date, "month")),
                          as.Date(floor_date(end_date, "month")),
                          by = "1 month")
      
      all_files <- c()
      
      for (month_start_raw in month_starts) {
        month_start <- as.Date(month_start_raw)  
        month_end <- min(month_start + months(1) - days(1), end_date)
        chunks <- generate_10_day_intervals(month_start, month_end)
        month_label <- format(month_start, "%Y-%m-%d")
        
        for (sensor in sensors) {
          month_data <- list()
          
          for (chunk in chunks) {
            chunk_start <- chunk[1]
            chunk_end <- chunk[2]
            days_range <- as.integer(chunk_end - chunk_start + 1)
            
            if (!is.null(area_coords)) {
              url <- paste(base_url, "area", "csv", map_key, sensor, area_coords, days_range, chunk_start, sep = "/")
            } else if (!is.null(country)) {
              url <- paste(base_url, "country", "csv", map_key, sensor, country, days_range, chunk_start, sep = "/")
            } else {
              stop("Please provide either area_coords or country")
            }
            
            cat(sprintf("📥 %s: %s to %s\n", sensor, chunk_start, chunk_end))
            tryCatch({
              response <- GET(url, timeout(60))
              if (status_code(response) == 200) {
                content_text <- content(response, "text", encoding = "UTF-8")
                lines <- read_lines(I(content_text))
                if (length(lines) > 1) {
                  df <- read_csv(I(content_text), show_col_types = FALSE)
                  month_data[[length(month_data) + 1]] <- df
                  cat("  ✓ Chunk has data\n")
                } else {
                  cat("  ⚠ Empty chunk\n")
                }
              } else {
                cat(sprintf("  ❌ HTTP error %d\n", status_code(response)))
              }
            }, error = function(e) {
              cat(sprintf("  ❌ Error: %s\n", e$message))
            })
          }
          
          # Save data for the month (if any)
          if (length(month_data) > 0) {
            combined <- bind_rows(month_data)
            if (nrow(combined) > 0) {
              filename <- sprintf("fire_alerts_%s_%s.csv", month_label, sensor)
              write_csv(combined, filename)
              all_files <- c(all_files, filename)
              cat(sprintf("📄 Saved %s (%d records)\n", filename, nrow(combined)))
            }
          }
          
          # Free up memory
          rm(month_data)
          gc()
        }
      }
      
      return(all_files)
    }
    
  )
}

# Example usage
main <- function() {
  MAP_KEY <- "193b52280657e5b21c20bdd911205bf9"  
  downloader <- NASAFireAlertsDownloader(MAP_KEY)
  
  start_date <- "2019-10-01"
  end_date <- "2019-12-01"
  area_coords <- "-120,-30,180,30"  
  sensors <- c("MODIS_SP","VIIRS_SNPP_SP","VIIRS_SNPP_NRT", "VIIRS_NOAA20_NRT","VIIRS_NOAA21_NRT","VIIRS_NOAA20_SP", "MODIS_NRT")
  
  files <- downloader$download_range(start_date, end_date, area_coords = area_coords, sensors = sensors)
  
  if (length(files) > 0) {
    cat("\n✅ Download complete. Files:\n")
    for (f in files) cat(sprintf("  - %s\n", f))
  } else {
    cat("\n❌ No files downloaded.\n")
  }
}

# Run main if interactive
if (interactive()) {
  main()
}

# note sensor availability 
# data_id,min_date,max_date
# MODIS_NRT,2025-02-01,2025-05-30
# MODIS_SP,2000-11-01,2025-01-31
# VIIRS_NOAA20_NRT,2025-02-01,2025-05-30
# VIIRS_NOAA20_SP,2018-04-01,2025-01-31
# VIIRS_NOAA21_NRT,2024-01-17,2025-05-30
# VIIRS_SNPP_NRT,2025-02-01,2025-05-30
# VIIRS_SNPP_SP,2012-01-20,2025-01-31
# LANDSAT_NRT,2022-06-20,2025-05-29
# GOES_NRT,2022-08-09,2025-05-30
# BA_MODIS,2000-11-01,2025-02-01
# BA_VIIRS,2012-03-01,2025-02-01
