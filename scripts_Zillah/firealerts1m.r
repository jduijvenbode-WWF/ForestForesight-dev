library(sf)
library(terra)
library(dplyr)
library(stringr)

# --- USER SETTINGS ---

# List of template raster tiles
template_tiles <- list.files("/Users/temp/Zillah Analytics/WWF/ff_folder/preprocessed/groundtruth", 
                             pattern = "2021-01-01_groundtruth1m.tif", full.names = TRUE, recursive = TRUE)

# Monthly fire alert GPKG files
gpkg_files <- list.files("/Users/temp/Zillah Analytics/WWF/ff_folder/fire/monthly_gpkg", pattern = "\\.gpkg$", full.names = TRUE)

# Output folder
output_dir <- "/Users/temp/Zillah Analytics/WWF/ff_folder/fire/tif_files"
dir.create(output_dir, showWarnings = FALSE)

# --- HELPERS ---
# Extract YYYY-MM from filename
get_month_str <- function(filename) {
  str_match(basename(filename), "fire_alerts_(\\d{4}-\\d{2})\\.gpkg")[, 2]
}

# Load fire alerts that fall within the extent of the template raster
load_fire_data_within_tile <- function(gpkg_path, tile_extent, tile_crs) {
  bbox_geom <- st_as_text(st_geometry(st_as_sfc(st_bbox(tile_extent, crs = tile_crs))))
  
  tryCatch({
    # Try fast filter
    st_read(gpkg_path, quiet = TRUE, wkt_filter = bbox_geom)
  }, error = function(e) {
    # Fallback if wkt_filter not supported
    fire_data <- st_read(gpkg_path, quiet = TRUE)
    bbox_poly <- st_as_sfc(st_bbox(tile_extent, crs = tile_crs))
    st_intersection(fire_data, bbox_poly)
  }) %>%
    st_transform(crs = tile_crs)
}

# Process one tile + one month, return raster layer
process_fire_month <- function(gpkg_path, template_raster) {
  month_str <- get_month_str(gpkg_path)
  message("  Processing month: ", month_str)
  
  tile_extent <- ext(template_raster)
  tile_crs <- crs(template_raster)
  
  fire_data <- load_fire_data_within_tile(gpkg_path, tile_extent, tile_crs)
  
  if (nrow(fire_data) == 0) {
    return(template_raster * 0)
  }
  
  # Rasterize total fire alerts per pixel
  fire_vect <- vect(fire_data)
  r_alerts <- rasterize(fire_vect, template_raster, fun = "length", background = 0)
  
  # Normalize by number of unique satellites
  n_satellites <- length(unique(fire_data$satellite))
  avg_alerts <- r_alerts / n_satellites
  names(avg_alerts) <- paste0("avg_alerts_", month_str)
  
  return(avg_alerts)
}

# --- MAIN LOOP ---

for (tile_path in template_tiles) {
  tile_base <- tools::file_path_sans_ext(basename(tile_path))
  tile_name <- str_extract(tile_base, "\\d{2}[NS]_\\d{3}[EW]")
  message("Processing tile: ", tile_name)
  
  template_raster <- rast(tile_path)
  
  for (gpkg_path in gpkg_files) {
    month_str <- get_month_str(gpkg_path)
    avg_alert_raster <- process_fire_month(gpkg_path, template_raster)
    
    # Save each tile-month combo as its own .tif
    dir.create(file.path(output_dir, tile_name), showWarnings = FALSE)
    new_date<- as.Date(paste0(month_str, "-01")) %m+% months(1)
    out_file <- file.path(output_dir,tile_name, paste0(tile_name, "_", new_date, "_firealerts1m.tif"))
    writeRaster(avg_alert_raster, out_file, overwrite = TRUE)
    message("  Saved: ", out_file)
  }
}



# ---- SETTINGS ----
base_dir <- "/Users/temp/Zillah Analytics/WWF/ff_folder/fire/tif_files"

# ---- FIND ALL TILE FOLDERS ----
tile_folders <- dir_ls(base_dir, type = "directory")

# ---- FUNCTIONS ----
get_tile <- function(path) basename(path)
get_date <- function(x) {
  # Make sure it matches the new YYYY-MM-DD format
  date_str <- str_extract(basename(x), "\\d{4}-\\d{2}-\\d{2}")
  ymd(date_str)
}

average_tifs <- function(files) {
  if (length(files) == 0) return(NULL)
  files <- files[file_exists(files)]
  if (length(files) == 0) return(NULL)
  mean(rast(files), na.rm = TRUE)
}

# ---- MAIN LOOP ----
for (folder in tile_folders) {
  tile <- get_tile(folder)
  message("Processing tile: ", tile)
  
  # files <- dir_ls(folder, regexp = "firealerts1m\\.tif$")
  # dates <- sort(unique(get_date(files)))
  # dates <- dates[dates >= ymd("2021-01-01")]
  dates <- daterange("2020-01-01", "2022-05-01")
  
  for (date in dates) {
    date=date <- as.Date(date)
    # Construct filenames using full date
    get_files <- function(start_offset, end_offset) {
      dates_seq <- seq(date %m-% months(start_offset), date %m-% months(end_offset), by = "1 month")
      formatted_dates <- format(dates_seq, "%Y-%m-%d")
      glue::glue("{folder}/{tile}_{formatted_dates}_firealerts1m.tif")
    }
    
    # 3-month avg
    r3 <- average_tifs(get_files(2, 0))
    if (!is.null(r3)) {
      out3 <- file.path(folder, str_glue("{tile}_{format(date, '%Y-%m-%d')}_firealerts3m.tif"))
      writeRaster(r3, out3, overwrite = TRUE)
    }
    
    # 6-month avg
    r6 <- average_tifs(get_files(5, 0))
    if (!is.null(r6)) {
      out6 <- file.path(folder, str_glue("{tile}_{format(date, '%Y-%m-%d')}_firealerts6m.tif"))
      writeRaster(r6, out6, overwrite = TRUE)
    }

    # 6–12 month avg
    r6_12 <- average_tifs(get_files(12, 6))
    if (!is.null(r6_12)) {
      out612 <- file.path(folder, str_glue("{tile}_{format(date, '%Y-%m-%d')}_firealerts6to12m.tif"))
      writeRaster(r6_12, out612, overwrite = TRUE)
    }
    
    message("  Done: ", format(date, "%Y-%m-%d"))
  }
}
