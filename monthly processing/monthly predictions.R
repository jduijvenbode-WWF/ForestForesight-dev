library(ForestForesight)
library(sf)
countries=vect(get(data("countries")))
ff_folder <- "D:/ff-dev/results"
proc_date <- format(Sys.Date(), "%Y-%m-01")
groups <- unique(countries$group)
setwd(ff_folder)
levels = c("medium","high","very high")

for (group in groups) {
  sel_countries <- countries[countries$group==group,]
  ff_cat(paste("processing",group))

  shape <- terra::aggregate(sel_countries)
  modelname <- group
  modelpath <- tail(list.files(file.path(ff_folder,"models",modelname),pattern = "model$",full.names = T), 1)

  tiffiles = paste0("predictions/",sel_countries$iso3,"/",sel_countries$iso3,"_",proc_date,".tif")
  risk_areas = paste0("risk_areas/",sel_countries$iso3,"/",sel_countries$iso3,"_",proc_date,".gpkg")
  if(!all(file.exists(tiffiles)) && !all(file.exists(risk_areas))){
    if (!file.exists(modelpath)) {stop(paste(modelpath,"does not exist"))}
  }
  tryCatch({
    result <- ff_run(shape = shape,
                     prediction_dates = proc_date,
                     ff_folder = ff_folder,
                     verbose = TRUE,pretrained_model_path = modelpath)
    for(x in seq(nrow(sel_countries))){
      sel_shape <- sel_countries[x,]
      sel_raster <- mask(crop(result$predictions,sel_shape),sel_shape)
      terra::writeRaster(sel_raster,tiffiles[x],overwrite = T)
      for (i in seq(3)) {
        sel_poly <- result$risk_zones[[1]][[i]][sel_shape]
        if (length(sel_poly) > 0) {
          writeVector(sel_poly,filename = risk_areas[x],layer=levels[i],insert = (i > 1),overwrite = (i == 1))
        }
      }
    }
  }, error = function(e) {
    # Print the error message
    print(paste("An error occurred:", e))
    # Continue the loop or execute other code as needed
  })
}


