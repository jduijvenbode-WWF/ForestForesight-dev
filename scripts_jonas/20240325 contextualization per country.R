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
arcpy_location <- '\"C:/Program Files/ArcGIS/Pro/bin/Python/envs/arcgispro-py3/python.exe\"'
script_location <- 'C:/data/git/ForestForesight-dev/scripts_jonas/tilepackager/map_tile_package.py'
ff_folder <- "C:/data/storage"
proc_date <- "2024-05-01"
train_start <-  "2023-05-01"
train_end <-  "2023-10-01"
countrynames <- c("Burundi","Laos","Colombia","Gabon","Sarawak","Bolivia","Madre de Dios","Suriname","Peru","Kalimantan")
isos <- c("BDI","LAO","COL","GAB","MYS","BOL","PER","SUR","PER","IDN")
gadm_s <- terra::vect("C:/data/storage/contextualization/GADM.gpkg")
for (x in seq(length(countrynames))) {
  country <- countrynames[x]
  cat(paste("processing",country,"\n"))
  countryiso <- isos[x]
  threshold <- 0.95
  dir.create(country)
  setwd(country)
  if (!file.exists(paste0(country,"_",proc_date,".tif"))) {
    shape <- terra::vect(countries)[which(countries$iso3 == countryiso),]
    if (country == "Sarawak") {shape <- terra::disagg(shape)[9]}
    if (country == "Kalimantan") {shape <- terra::disagg(shape)[133]}
    if (country == "Madre de Dios") {shape <- aggregate(gadm_s[which(gadm_s$"NAME_1" == "Madre de Dios"),])}
    modelname <- countries$group[which(countries$iso3 == countryiso)]
    modelpath <- file.path(ff_folder,"models",modelname,paste0(modelname,".model"))
    if (!file.exists(modelpath)) {stop(paste(modelpath,"does not exist"))}
    shape <- terra::project(shape,"epsg:3857")
    b <- terra::project(terra::rast(file.path(ff_folder,"predictions",countryiso,paste0(countryiso,"_",proc_date,".tif"))),"epsg:3857")
    if (country %in% c("Sarawak","Kalimantan","Madre de Dios")) {b <- terra::crop(terra::mask(b,shape),shape)}

    #########dashboard version 2########

    gadm <- gadm_s
    if (country == "Sarawak") {
      gadm <- gadm[which(gadm$COUNTRY == "Malaysia"), ]
      gadm <- gadm[terra::intersect(gadm,shape)]
    }else{if (country == "Kalimantan") {
      gadm <- gadm[which(gadm$COUNTRY == "Indonesia"), ]
      gadm <- gadm[terra::intersect(gadm,shape)]
    }else{if (country == "Madre de Dios") {
      gadm <- gadm[which(gadm$COUNTRY == "Peru"), ]
      gadm <- gadm[terra::intersect(gadm,shape)]
    }else{
      gadm <- gadm[which(gadm$COUNTRY == country), ]
    }
    }
    }

    gadm <- gadm[, c("NAME_0", "NAME_1", "NAME_2", "NAME_3")]


    ecobiome <- terra::vect("C:/data/storage/contextualization/ECOBIOME.gpkg",
                            extent = terra::ext(gadm))
    wdpa <- terra::vect("C:/data/storage/contextualization/WDPA.gpkg",
                        extent = terra::ext(gadm))
    ecobiome$ecobiome <- paste(ecobiome$Biome,ecobiome$Ecoregion,sep = "_")
    wdpa2 <- aggregate(wdpa)
    wdpa <- terra::intersect(wdpa, wdpa2)
    if (length(wdpa) > 0) {nonwdpa <- terra::as.polygons(terra::ext(wdpa)) - wdpa}else {nonwdpa <- terra::as.polygons(terra::ext(wdpa))}

    nonwdpa$status = "not protected"
    wdpa$status = "protected"
    wdpa <- rbind(wdpa, nonwdpa)
    wdpa <- aggregate(wdpa, by = "status")
    wdpa <- terra::disagg(wdpa)

    all = terra::intersect(gadm, ecobiome)
    all2 = terra::intersect(all, wdpa)

    colras <- b
    colras <- terra::mask(colras,gadm)
    colras[colras < 0.50] <- NA
    colras <- terra::crop(colras,gadm)
    threshold <- as.numeric(terra::global(colras,fun = quantile,probs = 0.90,na.rm = T))

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


    # Convert each part to polygons
    extpols <- create_grid(terra::ext(colras2),2,2)
    # Combine the resulting polygons
    pollist <- sapply(1:length(extpols),function(x) terra::as.polygons(terra::crop(colras2,extpols[x,]), dissolve = F))
    pols <- do.call(rbind, pollist)


    polvals = terra::extract(all2, terra::centroids(pols))
    polvals$events = NULL
    polvals$highalerts = NULL
    pols2 = cbind(pols, polvals)
    pols2$x = as.numeric(round(terra::crds(terra::centroids(pols2))[,1],3))
    pols2$y = as.numeric(round(terra::crds(terra::centroids(pols2))[,2],3))
    terra::writeVector(pols2, paste0(country,"_highalerts.shp"), overwrite = T)
    #code to extract the high alert values and amount of normal alerts for wdpa, ecobiome and gadm separately
    wdpa2 = terra::intersect(wdpa, aggregate(gadm))
    eventcount = colras > 0
    wdpa2$events <- terra::extract(eventcount,wdpa2,fun = "sum",na.rm = T)[,2]
    wdpa2$events[which(is.na(wdpa2$events))] = 0
    wdpa2$x = as.numeric(round(terra::crds(terra::centroids(wdpa2))[,1],3))
    wdpa2$y = as.numeric(round(terra::crds(terra::centroids(wdpa2))[,2],3))
    terra::writeVector(wdpa2, paste0(country,"_wdpa.shp"),overwrite = T)

    ecobiome2 <- terra::intersect(ecobiome, aggregate(gadm))
    ecobiome2$events <- terra::extract(eventcount,ecobiome2,fun = "sum",na.rm = T)[,2]
    ecobiome2$events[which(is.na(ecobiome2$events))] <- 0
    ecobiome2$x <- as.numeric(round(terra::crds(terra::centroids(ecobiome2))[,1],3))
    ecobiome2$y <- as.numeric(round(terra::crds(terra::centroids(ecobiome2))[,2],3))
    terra::writeVector(ecobiome2, paste0(country,"_ecobiome.shp"),overwrite = T)
    names(gadm) <- c("country","province","district","municipality")

    gadm$events <- terra::extract(eventcount,gadm,fun = "sum",na.rm = T)[,2]
    gadm$events[which(is.na(gadm$events))] <- 0
    gadm$highevents <- round(terra::extract(colras2,gadm,fun = "sum",na.rm = T)[,2])
    gadm$highevents[which(is.na(gadm$highevents))] <- 0
    gadm$label <- paste0(gadm$district,"\n",gadm$municipality)
    head(gadm)
    gadm$x = as.numeric(round(terra::crds(terra::centroids(gadm))[,1],3))
    gadm$y = as.numeric(round(terra::crds(terra::centroids(gadm))[,2],3))
    terra::writeVector(gadm, paste0(country,"_gadm.shp"),overwrite = T)
    files <- list.files()
    files <- files[unique(c(grep("dbf$",files),grep("prj$",files),grep("shp$",files),grep("shx$",files),grep("cpg$",files)))]
    if (file.exists(paste0(country,"_contextualization.zip"))) {file.remove(paste0(country,"_contextualization.zip"))}
    zip(paste0(country,"_contextualization.zip"),files)

    #tile the raster
    if (file.exists(file.path(getwd(),paste0(country,".tpkx")))) {file.remove(file.path(getwd(),paste0(country,".tpkx")))}
    system(paste(arcpy_location,script_location,paste0('\"',file.path(getwd(),paste0(country,".tif")),'\"'),paste0('\"',file.path(getwd(),paste0(country,".tpkx")),'\"')))
  }
  setwd("../")
}
