


tiles = list.files("D:/ff-dev/results/preprocessed/input")
t = 1
numtiles = length(tiles)
tempfile = "D:/ff-dev/temp.tif"
for (tile in tiles) {
  cat("Tile :", t, "from", numtiles, "\n")
  t = t + 1
  input_files = list.files(paste0("D:/ff-dev/results/preprocessed/input/", tile), full.names = T)
  template_raster = rast(list.files(paste0("D:/ff-dev/results/preprocessed/groundtruth/",tile), full.names = T)[1])
  for (file in input_files) {
    if (file.exists(tempfile)) {file.remove(tempfile)}
    file.rename(file,tempfile)
    rast_file = rast(tempfile)
    data_type <- terra::datatype(rast_file)
    if (global(is.na(rast_file), 'sum') > 0) {

      rast_file[is.na(rast_file)] = 0
    }
    # check if extent match
    if (ext(rast_file) != ext(template_raster)) {
      rast_file = extend(rast_file, ext(template_raster),fill = 0)

    }
    # set Na to 0

    #save file using same datatype
    writeRaster(rast_file, filename = file, datatype = data_type, overwrite = TRUE, gdal = "COMPRESS=ZSTD")
  }

}

