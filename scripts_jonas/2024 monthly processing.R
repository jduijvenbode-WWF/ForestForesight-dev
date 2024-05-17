library(ForestForesight)
library(sf)
data(countries)
ff_folder="C:/data/storage"
proc_date <- "2024-05-01"
train_start= "2023-05-01"
train_end= "2023-10-01"
countrynames=countries$iso3

proc_dates=rev(as.character(daterange("2023-06-01","2024-05-01")))
for(proc_date in proc_dates){
  for(x in seq(length(countrynames))){
    country <- countrynames[x]
    cat(paste("processing",country,"\n"))
    setwd("C:/data/storage/predictions/")
    if(!dir.exists(country)){dir.create(country)}
    setwd(country)
    if(!file.exists(paste0(country,"_",proc_date,".tif"))){
      cat(paste("processing",country,"for",proc_date,"\n"))
      shape <- terra::vect(countries)[which(countries$iso3 == country),]
      modelname=countries$group[which(countries$iso3==country)]
      modelpath=file.path(ff_folder,"models",modelname,paste0(modelname,".model"))
      if(!file.exists(modelpath)){stop(paste(modelpath,"does not exist"))}
      tryCatch({
        b <- train_predict_raster(shape = shape,
                                  prediction_date = proc_date,
                                  train_start = train_start,
                                  train_end = train_end,
                                  ff_folder = ff_folder,
                                  verbose = TRUE,
                                  model = modelpath)
      }, error = function(e) {
        # Print the error message
        print(paste("An error occurred:", e))
        # Continue the loop or execute other code as needed
      })
      terra::writeRaster(b,paste0(country,"_",proc_date,".tif"),overwrite = T)

    }
  }
}
