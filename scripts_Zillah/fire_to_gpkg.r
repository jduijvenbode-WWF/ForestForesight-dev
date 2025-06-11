# Fire Alerts Monthly GeoPackage Processor - Memory Efficient Version
# This script processes fire alert data month by month to handle large datasets
# and saves as GeoPackage files with satellite source information

# Load required libraries
library(sf)
library(dplyr)
library(readr)
library(lubridate)
library(stringr)
library(ggplot2)
library(scales)

# Function to extract satellite and date info from filename
extract_file_info <- function(filename) {
  # Extract date (YYYY-MM-DD format)
  date_match <- str_extract(filename, "\\d{4}-\\d{2}-\\d{2}")
  
  # Extract satellite type
  satellite <- case_when(
    str_detect(filename, "VIIRS_SNPP") ~ "VIIRS_SUOMI_NPP",
    str_detect(filename, "VIIRS_NOAA20") ~ "VIIRS_NOAA20",
    str_detect(filename, "VIIRS_NOAA21") ~ "VIIRS_NOAA21",
    str_detect(filename, "MODIS") ~ "MODIS",
    TRUE ~ "UNKNOWN"
  )
  
  # Extract processing type
  processing <- case_when(
    str_detect(filename, "_SP\\.csv") ~ "Standard Processing",
    str_detect(filename, "_NRT\\.csv") ~ "Near Real Time",
    TRUE ~ "Unknown Processing"
  )
  
  return(list(
    date = date_match,
    satellite = satellite,
    processing = processing,
    year_month = format(as.Date(date_match), "%Y-%m")
  ))
}

# Function to read and process a single CSV file
read_fire_csv <- function(filepath) {
  tryCatch({
    # Read the CSV file
    data <- read_csv(filepath, show_col_types = FALSE)
    
    # Extract file information
    filename <- basename(filepath)
    file_info <- extract_file_info(filename)
    
    # Check if latitude and longitude columns exist
    # Look for full words first, then partial matches
    lat_cols <- names(data)[str_detect(tolower(names(data)), "latitude|lat")]
    lon_cols <- names(data)[str_detect(tolower(names(data)), "longitude|lon")]
    
    if(length(lat_cols) == 0 || length(lon_cols) == 0) {
      cat("Warning: No lat/lon columns found in", filename, "\n")
      cat("Available columns:", paste(names(data), collapse = ", "), "\n")
      return(NULL)
    }
    
    # Use the first lat/lon columns found (prioritize full names)
    lat_col <- lat_cols[which(tolower(lat_cols) == "latitude")][1]
    if(is.na(lat_col)) lat_col <- lat_cols[1]
    
    lon_col <- lon_cols[which(tolower(lon_cols) == "longitude")][1] 
    if(is.na(lon_col)) lon_col <- lon_cols[1]
    
    # Add metadata columns
    data$satellite <- file_info$satellite
    data$processing_type <- file_info$processing
    data$source_file <- filename
    data$date_processed <- file_info$date
    data$year_month <- file_info$year_month
    
    # Rename lat/lon columns to standard names if needed
    if(lat_col != "latitude") {
      data <- data %>% rename(latitude = !!lat_col)
    }
    if(lon_col != "longitude") {
      data <- data %>% rename(longitude = !!lon_col)
    }
    
    # Filter out invalid coordinates and keep only essential columns
    data <- data %>%
      filter(!is.na(latitude), !is.na(longitude),
             latitude >= -90, latitude <= 90,
             longitude >= -180, longitude <= 180) %>%
      # Keep only essential columns to avoid binding issues
      select(latitude, longitude, satellite, processing_type, source_file, date_processed, year_month)
    
    cat("  Processed", filename, "- Found", nrow(data), "valid fire points\n")
    return(data)
    
  }, error = function(e) {
    cat("  Error processing", filepath, ":", e$message, "\n")
    return(NULL)
  })
}

# Function to group files by month
group_files_by_month <- function(csv_files) {
  file_info_list <- list()
  
  for(file in csv_files) {
    filename <- basename(file)
    info <- extract_file_info(filename)
    if(!is.null(info$year_month)) {
      file_info_list[[file]] <- info
    }
  }
  
  # Group files by year_month
  files_by_month <- split(names(file_info_list), 
                          sapply(file_info_list, function(x) x$year_month))
  
  return(files_by_month)
}

# Function to process files for a single month
process_monthly_files <- function(monthly_files, year_month, output_directory) {
  
  cat("\n=== Processing", year_month, "===\n")
  cat("Files to process:", length(monthly_files), "\n")
  
  monthly_data_list <- list()
  
  # Read all CSV files for this month
  for(file in monthly_files) {
    data <- read_fire_csv(file)
    if(!is.null(data) && nrow(data) > 0) {
      monthly_data_list[[basename(file)]] <- data
    }
  }
  
  if(length(monthly_data_list) == 0) {
    cat("No valid data found for", year_month, "\n")
    return(NULL)
  }
  
  # Combine data for this month
  combined_monthly_data <- bind_rows(monthly_data_list)
  
  if(nrow(combined_monthly_data) == 0) {
    cat("No fire points found for", year_month, "\n")
    return(NULL)
  }
  
  cat("Total fire points for", year_month, ":", nrow(combined_monthly_data), "\n")
  
  # Create spatial data frame
  sf_data <- st_as_sf(combined_monthly_data, 
                      coords = c("longitude", "latitude"), 
                      crs = 4326)  # WGS84
  
  # Create summary statistics
  satellite_summary <- combined_monthly_data %>%
    group_by(satellite, processing_type) %>%
    summarise(
      point_count = n(),
      files_count = n_distinct(source_file),
      date_range = paste(min(date_processed, na.rm = TRUE), 
                         max(date_processed, na.rm = TRUE), 
                         sep = " to "),
      .groups = 'drop'
    ) %>%
    mutate(year_month = year_month)
  
  # Generate output filename
  output_file <- file.path(output_directory, paste0("fire_alerts_", year_month, ".gpkg"))
  
  # Write to GeoPackage
  st_write(sf_data, output_file, 
           layer = "fire_points", 
           delete_dsn = TRUE, 
           quiet = TRUE)
  
  # Write summary table to the same GeoPackage (convert to sf object for consistency)
  summary_sf <- satellite_summary %>%
    # Create a dummy geometry for the summary table
    mutate(geometry = st_sfc(st_point(c(0, 0)), crs = 4326)) %>%
    st_as_sf()
  
  st_write(summary_sf, 
           output_file, 
           layer = "summary", 
           append = TRUE,
           quiet = TRUE)
  
  cat("Saved:", output_file, "\n")
  
  # Print summary for this month
  cat("Satellites included:\n")
  for(i in 1:nrow(satellite_summary)) {
    cat("  -", satellite_summary$satellite[i], 
        "(", satellite_summary$processing_type[i], "):",
        satellite_summary$point_count[i], "points from",
        satellite_summary$files_count[i], "files\n")
  }
  
  # Clean up memory
  rm(combined_monthly_data, sf_data, monthly_data_list)
  gc()  # Force garbage collection
  
  return(satellite_summary)
}

# Main processing function - Memory efficient version
process_fire_alerts <- function(input_directory = ".", output_directory = "./monthly_gpkg") {
  
  # Create output directory if it doesn't exist
  if (!dir.exists(output_directory)) {
    dir.create(output_directory, recursive = TRUE)
  }
  
  # Find all CSV files matching the pattern
  csv_files <- list.files(input_directory, 
                          pattern = "fire_alerts_.*\\.csv$", 
                          full.names = TRUE)
  
  if(length(csv_files) == 0) {
    stop("No fire alert CSV files found in the specified directory")
  }
  
  cat("Found", length(csv_files), "CSV files to process\n")
  
  # Group files by month
  files_by_month <- group_files_by_month(csv_files)
  
  if(length(files_by_month) == 0) {
    stop("No valid date information could be extracted from filenames")
  }
  
  cat("Found", length(files_by_month), "months to process:", 
      paste(names(files_by_month), collapse = ", "), "\n")
  
  # Process each month separately
  all_summaries <- list()
  
  for(year_month in names(files_by_month)) {
    monthly_files <- files_by_month[[year_month]]
    
    summary <- process_monthly_files(monthly_files, year_month, output_directory)
    
    if(!is.null(summary)) {
      all_summaries[[year_month]] <- summary
    }
    
    # Small pause to allow system to clean up memory
    Sys.sleep(0.1)
  }
  
  # Combine all summaries
  if(length(all_summaries) > 0) {
    overall_summary <- bind_rows(all_summaries)
    
    # Save overall summary
    summary_file <- file.path(output_directory, "processing_summary.csv")
    write_csv(overall_summary, summary_file)
    
    cat("\n=== PROCESSING COMPLETE ===\n")
    cat("Monthly GeoPackage files saved in:", output_directory, "\n")
    cat("Processing summary saved as:", summary_file, "\n")
    cat("Total months processed:", length(all_summaries), "\n")
    cat("Total fire points across all months:", sum(overall_summary$point_count), "\n")
    
    return(overall_summary)
  } else {
    cat("No data was successfully processed\n")
    return(NULL)
  }
}

# Utility function to check available files and their grouping
preview_file_grouping <- function(input_directory = ".") {
  csv_files <- list.files(input_directory, 
                          pattern = "fire_alerts_.*\\.csv$", 
                          full.names = TRUE)
  
  if(length(csv_files) == 0) {
    cat("No fire alert CSV files found\n")
    return(NULL)
  }
  
  files_by_month <- group_files_by_month(csv_files)
  
  cat("=== FILE GROUPING PREVIEW ===\n")
  for(month in names(files_by_month)) {
    cat("\n", month, "(", length(files_by_month[[month]]), "files):\n")
    for(file in files_by_month[[month]]) {
      info <- extract_file_info(basename(file))
      cat("  -", basename(file), "(", info$satellite, "-", info$processing, ")\n")
    }
  }
  
  return(files_by_month)
}

# Function to create time series plot from summary data
plot_fire_alerts_timeseries <- function(summary_data, output_directory = "./monthly_gpkg") {
  
  # Prepare data for plotting
  plot_data <- summary_data %>%
    mutate(
      # Convert year_month to proper date (first day of month)
      date = as.Date(paste0(year_month, "-01")),
      # Create combined satellite-processing label
      satellite_processing = paste(satellite, processing_type, sep = " - ")
    ) %>%
    arrange(date, satellite_processing)
  
  # Create the plot
  p <- ggplot(plot_data, aes(x = date, y = point_count, 
                             color = satellite_processing, 
                             linetype = satellite_processing)) +
    geom_line(size = 1.2) +
    geom_point(size = 2.5, alpha = 0.8) +
    scale_x_date(date_labels = "%Y-%m", date_breaks = "2 months") +
    scale_y_continuous(labels = comma_format()) +
    labs(
      title = "Fire Alert Points Over Time by Satellite and Processing Type",
      subtitle = paste("Total points processed:", format(sum(plot_data$point_count), big.mark = ",")),
      x = "Month",
      y = "Number of Fire Points",
      color = "Satellite - Processing",
      linetype = "Satellite - Processing"
    ) +
    theme_minimal() +
    theme(
      plot.title = element_text(size = 16, face = "bold"),
      plot.subtitle = element_text(size = 12),
      axis.text.x = element_text(angle = 45, hjust = 1),
      legend.position = "bottom",
      legend.title = element_text(face = "bold"),
      panel.grid.minor = element_blank(),
      panel.grid.major.x = element_line(colour = "grey80"),
      panel.grid.major.y = element_line(colour = "grey80")
    ) +
    guides(
      color = guide_legend(ncol = 2),
      linetype = guide_legend(ncol = 2)
    )
  
  # Print the plot
  print(p)
  
  # Save the plot
  plot_file <- file.path(output_directory, "fire_alerts_timeseries.png")
  ggsave(plot_file, p, width = 14, height = 8, dpi = 300, bg = "white")
  
  cat("Time series plot saved as:", plot_file, "\n")
  
  # Also create a faceted version for better readability
  p_faceted <- ggplot(plot_data, aes(x = date, y = point_count, 
                                     color = satellite_processing)) +
    geom_line(size = 1.2) +
    geom_point(size = 2.5, alpha = 0.8) +
    facet_wrap(~satellite_processing, scales = "free_y", ncol = 2) +
    scale_x_date(date_labels = "%Y-%m", date_breaks = "2 months") +
    scale_y_continuous(labels = comma_format()) +
    labs(
      title = "Fire Alert Points Over Time by Satellite and Processing Type",
      subtitle = "Faceted view for better comparison",
      x = "Month",
      y = "Number of Fire Points"
    ) +
    theme_minimal() +
    theme(
      plot.title = element_text(size = 16, face = "bold"),
      plot.subtitle = element_text(size = 12),
      axis.text.x = element_text(angle = 45, hjust = 1),
      legend.position = "none",
      panel.grid.minor = element_blank(),
      panel.grid.major.x = element_line(colour = "grey80"),
      panel.grid.major.y = element_line(colour = "grey80"),
      strip.text = element_text(face = "bold")
    )
  
  # Save the faceted plot
  plot_file_faceted <- file.path(output_directory, "fire_alerts_timeseries_faceted.png")
  ggsave(plot_file_faceted, p_faceted, width = 14, height = 10, dpi = 300, bg = "white")
  
  cat("Faceted time series plot saved as:", plot_file_faceted, "\n")
  
  # Print summary statistics
  cat("\n=== SUMMARY STATISTICS ===\n")
  
  summary_stats <- plot_data %>%
    group_by(satellite_processing) %>%
    summarise(
      total_points = sum(point_count),
      avg_monthly_points = round(mean(point_count)),
      min_monthly_points = min(point_count),
      max_monthly_points = max(point_count),
      months_active = n(),
      .groups = 'drop'
    ) %>%
    arrange(desc(total_points))
  
  print(summary_stats)
  
  return(list(plot = p, faceted_plot = p_faceted, summary_stats = summary_stats))
}
