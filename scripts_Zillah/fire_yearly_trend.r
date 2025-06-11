# ---- SETTINGS ----
base_dir <- "/Users/temp/Zillah Analytics/WWF/ff_folder/preprocessed/input"

# ---- FIND ALL TILE FOLDERS ----
tile_folders <- dir_ls(base_dir, type = "directory")
dates= daterange("2022-01-01", "2025-05-01")

# ---- FUNCTIONS ----
get_tile <- function(path) basename(path)


for (folder in tile_folders) {
  tile <- get_tile(folder)
  files <- dir_ls(folder, regexp = "lastthreemonths.tif$")
  message("Processing tile: ", tile)
  for (date in dates){
    date= as.Date(date)
    current_3m = rast(as.character(grep(date,files,value = TRUE)))
    last_year_3m = rast(as.character(grep(date-years(1),files,value = TRUE)))
    yearly_trend = current_3m - last_year_3m
    out_file <- file.path(folder, str_glue("{tile}_{format(date, '%Y-%m-%d')}_yearlytrend.tif"))
    writeRaster(yearly_trend, out_file, overwrite = TRUE)
    ff_cat(date, ":✅ yearly trend saved" )
  }}
