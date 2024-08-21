library(ForestForesight)
library(sf)
create_grid <- function(poly,num_rows,num_cols) {
  # Calculate the bounding box of the polygon

  # Create the grid
  grid <- terra::vect(st_make_grid(poly, n = c(num_cols, num_rows), what = "polygons"))

  return(grid)
}
data(countries)
setwd("C:/data/dashboard_data")
gadm_s <- terra::vect("C:/data/storage/contextualization/GADM.gpkg")
arcpy_location <- '\"C:/Program Files/ArcGIS/Pro/bin/Python/envs/arcgispro-py3/python.exe\"'
script_location <- 'C:/data/git/ForestForesight-dev/scripts_jonas/tilepackager/map_tile_package.py'
ff_folder <- "C:/data/storage"
proc_date <- "2024-08-01"

countrynames <- c("Laos","Colombia","Gabon","Bolivia","Madre de Dios","Suriname","Peru","Kalimantan","Guaviare")
isos <- c("LAO","COL","GAB","BOL","PER","SUR","PER","IDN","COL")

for (x in seq(length(countrynames))) {
  country <- countrynames[x]
  cat(paste("processing",country,"\n"))
  countryiso <- isos[x]
  setwd("C:/data/dashboard_data")
  dir.create(country)
  setwd(country)
  if (!file.exists(paste0(proc_date,".txt"))) {
    #if(T){
    cat("processing shape\n")
    shape <- terra::vect(countries)[which(countries$iso3 == countryiso),]
    if (country == "Sarawak") {shape <- terra::disagg(shape)[9]}
    if (country == "Kalimantan") {shape <- terra::disagg(shape)[133]}
    if (country == "Madre de Dios") {shape <- aggregate(gadm_s[which(gadm_s$"province" == "Madre de Dios"),])}
    if (country == "Guaviare") {
      shape <- aggregate(gadm_s[which(gadm_s$"province" == "Guaviare"),])}

    shape <- terra::project(shape,"epsg:3857")
    b <- terra::project(terra::rast(file.path(ff_folder,"predictions",countryiso,paste0(countryiso,"_",proc_date,".tif"))),"epsg:3857")
    if (country %in% c("Sarawak","Kalimantan","Madre de Dios")) {b <- terra::crop(terra::mask(b,shape),shape)}

    #########dashboard version 2########
    cat("preprocessing open datasets\n")
    gadm <- gadm_s
    if (country == "Sarawak") {
      gadm <- gadm[which(gadm$country == "Malaysia"), ]
      gadm <- gadm[terra::intersect(gadm,project(shape,gadm))]
    }else{if (country == "Kalimantan") {
      gadm <- gadm[which(gadm$country == "Indonesia"), ]
      gadm <- gadm[terra::intersect(gadm,project(shape,gadm))]
    }else{if (country == "Madre de Dios") {
      gadm <- gadm[which(gadm$country == "Peru"), ]
      gadm <- gadm[terra::intersect(gadm,project(shape,gadm))]
    }else{if (country == "Guaviare") {
      gadm <- gadm[which(gadm$country == "Colombia"), ]
      gadm <- gadm[terra::intersect(gadm,project(shape,gadm))]
    }else{
      gadm <- gadm[which(gadm$country == country), ]
    }
    }
    }}

  gadm <- gadm[, c("country", "province", "district", "municipality")]
  if(is.lonlat(gadm)){gadm=project(gadm,shape)}

  ecobiome <- terra::vect("C:/data/storage/contextualization/ECOBIOME.gpkg",
                          extent = terra::ext(project(gadm,crs("epsg:4326"))))
  wdpa <- terra::vect("C:/data/storage/contextualization/WDPA.gpkg",
                      extent = terra::ext(project(gadm,crs("epsg:4326"))))
  if(is.lonlat(wdpa)){wdpa=project(wdpa,shape)}
  if(is.lonlat(ecobiome)){ecobiome=project(ecobiome,shape)}
  ecobiome$ecobiome <- paste(ecobiome$Biome,ecobiome$Ecoregion,sep = "_")
  #wdpa2 <- aggregate(wdpa)
  #wdpa <- terra::intersect(wdpa, wdpa2)
  #if (length(wdpa) > 0) {nonwdpa <- terra::as.polygons(terra::ext(wdpa)) - wdpa}else {nonwdpa <- terra::as.polygons(terra::ext(wdpa))}

  #nonwdpa$status = "not protected"
  wdpa$status = "protected"

  #wdpa <- aggregate(wdpa, by = "status")
  #wdpa <- terra::disagg(wdpa)

  all = terra::intersect(gadm, ecobiome)
  all2 = terra::intersect(all, wdpa)
  cat("reclassifying raster\n")
  colras <- b

  colras <- terra::mask(colras,gadm)
  colras[colras < 0.50] <- NA
  colras <- terra::crop(colras,gadm)
  threshold <- as.numeric(terra::global(colras,fun = quantile,probs = 0.90,na.rm = T))
  if(country=="Guaviare"){threshold <- as.numeric(terra::global(colras,fun = quantile,probs = 0.70,na.rm = T))}
  names(colras) <- paste0("Forest Foresight predictions",country)
  terra::writeRaster(colras,paste0(country,".tif"),overwrite = T)

  vals <- terra::extract(colras > 0, all2, fun = "sum", na.rm = T)[, 2]
  vals[is.na(vals)] <- 0
  highalertvals <- terra::extract(colras > threshold, all2, fun = "sum", na.rm = T)[, 2]
  highalertvals[is.na(highalertvals)] <- 0
  all2$events <- vals
  all2$highalerts <- highalertvals
  all2$agg_n <- NULL
  names(all2) = c(
    "country",
    "province",
    "district",
    "municipality",
    "ecoregion",
    "biome",
    "ecobiome",
    "status",
    "events",
    "highalerts"
  )
  all2$proc_date <- proc_date
  terra::writeVector(terra::centroids(all2), paste0(country,".overview.shp"), overwrite = T)

  colras2 = colras
  colras2[colras2 < threshold] = NA

  # Split the raster into four parts based on its extent

  cat("creating high likelihood polygons\n")
  # Convert each part to polygons
  extpols <- create_grid(terra::ext(colras2),2,2)
  # Combine the resulting polygons
  pollist <- sapply(1:length(extpols),function(x) terra::as.polygons(terra::crop(colras2,extpols[x,]), dissolve = F))
  pols <- do.call(rbind, pollist)


  polvals = terra::extract(all2, terra::centroids(pols))
  polvals$events = NULL
  polvals$highalerts = NULL
  if(sum(duplicated(polvals$id.y))>0){polvals=polvals[-which(duplicated(polvals$id.y)),]}

  pols2 = cbind(pols, polvals)
  pols2$x = as.numeric(round(terra::crds(terra::centroids(pols2))[,1],3))
  pols2$y = as.numeric(round(terra::crds(terra::centroids(pols2))[,2],3))
  terra::writeVector(pols2, paste0(country,"_highalerts.shp"), overwrite = T)
}
cat("creating tpkx\n")
if (file.exists(file.path(getwd(),paste0(country,"_",proc_date,".tpkx")))) {file.remove(file.path(getwd(),paste0(country,"_",proc_date,".tpkx")))}
system(paste(arcpy_location,script_location,paste0('\"',file.path(getwd(),paste0(country,".tif")),'\"'),paste0('\"',file.path(getwd(),paste0(country,"_",proc_date,".tpkx")),'\"')))
write("processing finished",file.path(getwd(),paste0(proc_date,".txt")))



}
