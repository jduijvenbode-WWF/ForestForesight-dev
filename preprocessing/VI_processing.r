library(stringr)
library(terra)
library(ForestForesight)

tiles <- get(data("gfw_tiles"))$tile_id
global_file_dir <-"/Users/temp/Zillah Analytics/WWF/ff_folder/VI/" # map containing EVI and NBR subfolders where the GEE downloads are 
template_raster_path<- "/Users/temp/Zillah Analytics/WWF/ff_folder/input/"
template_raster_name <- "2022-01-01_firealerts1m.tif"
vis <- c("NBR", "EVI")
remove_global_tif <- FALSE
output_dir<- "/Users/temp/Zillah Analytics/WWF/ff_folder/VI/tif_files"     
overwrite<-TRUE
target_month <- NULL
date <- if(is.null(target_month)) floor_date(Sys.Date(), "month") else as.Date(paste0(target_month, "-01"))
n_exp=2

for (vi in vis){
  date_files<- list.files(paste0(global_file_dir, vi), pattern= as.character(date), full.names = TRUE)
  cat("Starting processing for", vi, as.character(date), "\n")
  cat("Processing", length(tiles), "tiles per date\n")
  cat("  Found", length(date_files), "sharded files to mosaic\n")
  # Check if template exists
  if (length(date_files) != n_exp) {
    cat("    Warning: Not all files are available for ", date, "\n")
    next
  }
  # MEMORY EFFICIENT: Direct merge without pre-loading
  cat("  Merging", length(date_files), "files...")
  if (length(date_files) == 1) {
    raster_date <- rast(date_files[1])
  } else {
    raster_date <- do.call(merge, lapply(date_files, rast))
  }
  cat(" done\n")
  
  
  tiles_processed <- 0
  
  for (tile in tiles){
    template_file <- paste0(template_raster_path, tile,"/", tile,"_", template_raster_name)
    
    # Check if template exists
    if (!file.exists(template_file)) {
      cat("    Warning: Template not found for", tile, "\n")
      next
    }
    
    template <- rast(template_file)
    output_filename <- paste0(tile, "_", date,"_", vi, ".tif")
    output_dir_tile <- paste0(output_dir, "/", tile)
    
    # Create output directory if it doesn't exist
    if (!dir.exists(output_dir_tile)) {
      dir.create(output_dir_tile, recursive = TRUE)
    }
    
    output_path <- file.path(output_dir_tile, output_filename)
    
    # Skip if file exists and overwrite is FALSE
    if (file.exists(output_path) && !overwrite) {
      next
    }
    
    # MEMORY-EFFICIENT: Crop each input file to tile extent, then merge only relevant parts
    tile_extent <- ext(template)
    relevant_files <- c()
    temp_cropped <- list()
    
    for (j in seq_along(date_files)) {
      # Load just the header to check extent overlap
      temp_rast <- rast(date_files[j])
      if (relate(tile_extent, ext(temp_rast), "intersects")) {
        # Only crop and keep if it intersects with tile
        cropped <- crop(temp_rast, tile_extent, mask = FALSE)
        if (ncell(cropped) > 0) {
          temp_cropped[[length(temp_cropped) + 1]] <- cropped
        }
      }
      rm(temp_rast)
      gc()
    }
    
    # Merge only the relevant cropped pieces
    if (length(temp_cropped) == 0) {
      cat("    Warning: No data found for tile", tile, "\n")
      next
    } else if (length(temp_cropped) == 1) {
      tile_raster <- temp_cropped[[1]]
    } else {
      tile_raster <- do.call(merge, temp_cropped)
    }
    
    # Resample to template
    resampled <- resample(tile_raster, template, method = "bilinear")
    
    # Convert 0s to NA before writing
    resampled[resampled == 0] <- NA
    
    # Write with LZW compression
    writeRaster(round(resampled), output_path, 
                overwrite = overwrite, datatype = "INT1U",
                gdal = c("COMPRESS=LZW"))
    
    # Clean up tile-specific objects
    rm(template, tile_raster, resampled, temp_cropped)
    gc()
    
    tiles_processed <- tiles_processed + 1
  }
  
  cat("  Completed", tiles_processed, "tiles for", as.character(date), "\n\n")
  
  # Force garbage collection after processing all tiles
  gc()
  
  if (remove_global_tif && tiles_processed == length(tiles)) {
    cat("  All tiles processed, removing global tif files for", date, "\n")
    unlink(date_files)
  } else if (remove_global_tif) {
    cat("  Skipping deletion: only", tiles_processed, "of", length(tiles), "tiles processed for", date, "\n")
  }
  
  
}

cat("Processing complete!\n")


