library(ForestForesight)
library(sf)
data(countries)
ff_folder="D:/ff-dev/results"
proc_dates <- c("2024-01-01")
countrynames=countries$iso3

AUS/AUS_2023-10-01.tif
AUS/AUS_2023-11-01.tif
BRA/BRA_2024-01-01.tif
DZA/DZA_2023-10-01.tif
DZA/DZA_2023-11-01.tif
ESH/ESH_2023-10-01.tif
ESH/ESH_2023-11-01.tif

for(proc_date in proc_dates){
  for(x in c(76)){
  #for(x in seq(length(countrynames))){
    country <- countrynames[x]
    cat(paste("processing",country,"\n"))
    setwd("D:/ff-dev/results/predictions")
    if(!dir.exists(country)){dir.create(country)}
    setwd(country)
    if(!file.exists(paste0(country,"_",proc_date,".tif"))){
      cat(paste("processing",country,"for",proc_date,"\n"))
      shape <- terra::vect(countries)[which(countries$iso3 == country),]
      modelname=countries$group[which(countries$iso3==country)]
      modelpath=tail(list.files(file.path(ff_folder,"models",modelname),pattern="model$",full.names = T),1)
      if(!file.exists(modelpath)){stop(paste(modelpath,"does not exist"))}
      tryCatch({
        b <- ff_run(shape = shape,
                                  prediction_dates = proc_date,
                                  ff_folder = ff_folder,
                                  verbose = TRUE,
                                  trained_model = modelpath)

        terra::writeRaster(b,paste0(country,"_",proc_date,".tif"),overwrite = T)
      }, error = function(e) {
        # Print the error message
        print(paste("An error occurred:", e))
        # Continue the loop or execute other code as needed
      })
    }
  }
}
