library(ForestForesight)
library(terra)
library(zip)



setwd("C:/data/dashboard_data")
ff_folder <- "C:/data/storage"
proc_date <- "2024-10-01"
arcpy_location <- '\"C:/Program Files/ArcGIS/Pro/bin/Python/envs/arcgispro-py3/python.exe\"'
script_location <- 'C:/data/git/ForestForesight-dev/scripts_jonas/tilepackager/map_tile_package.py'

countrynames <- c("Laos", "Gabon", "Bolivia", "Peru", "Kalimantan", "Guaviare")
isos <- c("LAO", "GAB", "BOL", "PER", "IDN", "COL")

for (x in rev(seq(length(countrynames)))) {
  country <- countrynames[x]
  cat(paste("Processing", country, "\n"))
  countryiso <- isos[x]
  setwd("C:/data/dashboard_data")
  dir.create(country, showWarnings = FALSE)
  setwd(country)

  if (!file.exists(paste0(proc_date, ".txt"))) {
    cat("Processing shape\n")
    shape <- terra::vect(countries)[which(countries$iso3 == countryiso),]
    if (country == "Sarawak") {shape <- terra::disagg(shape)[9]}
    if (country == "Kalimantan") {shape <- terra::disagg(shape)[133]}
    if(country=="Guaviare") {shape=terra::vect("../AOIs/Guaviare.gpkg") }
    shape <- terra::project(shape, "epsg:3857")

    b <- terra::project(terra::rast(file.path(ff_folder, "predictions", countryiso, paste0(countryiso, "_", proc_date, ".tif"))), "epsg:3857")
    if (country %in% c("Sarawak", "Kalimantan", "Madre de Dios")) {b <- terra::crop(terra::mask(b, shape), shape)}

    cat("Reclassifying raster\n")
    colras <- b
    colras <- terra::mask(colras, shape)
    colras[colras < 0.50] <- NA
    colras <- terra::crop(colras, shape)
    names(colras) <- paste0("Forest Foresight predictions ", country)
    terra::writeRaster(colras, paste0(country, ".tif"), overwrite = TRUE)

    # Create risk polygons
    medium_risk <- ff_polygonize(colras, threshold = "medium", output_file = paste0(country, "_medium_risk.shp"),verbose = T,calc_max = T)
    high_risk <- ff_polygonize(colras, threshold = "high", output_file = paste0(country, "_high_risk.shp"),verbose=T,calc_max = T,contain_polygons = medium_risk)
    highest_risk <- ff_polygonize(colras, threshold = "very high", output_file = paste0(country, "_highest_risk.shp"),verbose=T,calc_max = T, contain_polygons = high_risk)

    # Create tpkx
    cat("Creating tpkx\n")
    tpkx_file <- paste0(country, "_", proc_date, ".tpkx")
    if (file.exists(tpkx_file)) {file.remove(tpkx_file)}
    #system(paste(arcpy_location, script_location, paste0('\"', file.path(getwd(), paste0(country, ".tif")), '\"'), paste0('\"', file.path(getwd(), tpkx_file), '\"')))

    # Create zip file with shapefiles
    zip_file <- paste0(country, "_risk_areas.zip")
    files=list.files(pattern="_risk\\.")
    zip::zip(zip_file, files = files)

    write("Processing finished", file.path(getwd(), paste0(proc_date, ".txt")))
  }
}
