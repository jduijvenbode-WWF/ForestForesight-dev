


tiles = list.files("D:/ff-dev/results/preprocessed/input")
t = 1
numtiles = length(tiles)
tempfile = "D:/ff-dev/temp.tif"
for (tile in tiles) {
  cat("Tile :", t, "from", numtiles, "\n")
  t = t + 1
  input_files = c(
    list.files(paste0("D:/ff-dev/results/preprocessed/input/", tile), full.names = T),
    list.files(paste0("D:/ff-dev/results/preprocessed/groundtruth/", tile), full.names = T))
  template_raster = terra::rast(list.files(paste0("D:/ff-dev/results/preprocessed/groundtruth/",tile), full.names = T)[1])
  for (file in input_files) {
    if (file.exists(tempfile)) {file.remove(tempfile)}
    file.rename(file,tempfile)
    rast_file = terra::rast(tempfile)

    data_type <- terra::datatype(rast_file)
    names(rast_file)=gsub(".tif","",basename(file))
    crs(rast_file)=crs("epsg:4326")
    if (data_type == "INT2U") {rast_file[rast_file == 65535] = 0}
    rast_file[is.na(rast_file)] = 0
    # check if extent match
    if (terra::ext(rast_file) != terra::ext(template_raster)) {
      rast_file = terra::extend(rast_file, terra::ext(template_raster),fill = 0)

    }
    # set Na to 0

    #save file using same datatype
    terra::writeRaster(rast_file, filename = file, datatype = data_type, overwrite = TRUE, gdal = "COMPRESS=ZSTD")

  }

}

