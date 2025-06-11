library(ForestForesight)
dates <- daterange("2024-07-01", "2025-05-01")
tiles <- vect(get(data(gfw_tiles)))$tile_id

for (tile in tiles) {
  message(paste0("\n📦 Starting tile: ", tile, " (", which(tiles == tile), " of ", length(tiles), ")"))
  
  for (date in dates) {
    out_file <- paste0("/Users/temp/Zillah Analytics/WWF/ff_folder/preprocessed/input/", tile, "/", tile, "_", date, "_deforestscore.tif")
    
    message(paste0("🗓️  Processing date: ", date))
    message("   🔄 Loading confidence and timesinceloss rasters...")
    
    conf <- get_raster("/Users/temp/Zillah Analytics/WWF/ff_folder/preprocessed", date = date, feature = "confidence", tile = tile, return_raster = TRUE)
    tsl <- get_raster("/Users/temp/Zillah Analytics/WWF/ff_folder/preprocessed", date = date, feature = "timesinceloss", tile = tile, return_raster = TRUE)
    
    message("   🧮 Calculating deforestation score...")
    def_score <- conf * tsl
    
    message(paste0("   💾 Saving to: ", out_file))
    writeRaster(def_score, out_file, overwrite = TRUE)
    
    message("   ✅ Done for this date.\n")
  }
  
  message(paste0("🏁 Finished tile: ", tile, "\n-----------------------------"))
}
message("🎉 All processing completed.")
