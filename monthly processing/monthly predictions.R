library(ForestForesight)
library(sf)
data(countries)
ff_folder <- "C:/data/storage"
proc_dates <- c("2024-12-01")
countrynames <- countries$iso3


for (proc_date in proc_dates) {
  for (x in seq(length(countrynames))) {
    country <- countrynames[x]
    ff_cat(paste("processing",country))
    setwd(file.path(ff_folder,"predictions"))
    if (!dir.exists(country)) {dir.create(country)}
    setwd(country)
    if (!file.exists(paste0(country,"_",proc_date,".tif"))) {
      ff_cat(paste("processing",country,"for",proc_date))
      shape <- terra::vect(countries)[which(countries$iso3 == country),]
      modelname <- countries$group[which(countries$iso3 == country)]
      modelpath <- tail(list.files(file.path(ff_folder,"models",modelname),pattern = "model$",full.names = T), 1)
      if (!file.exists(modelpath)) {stop(paste(modelpath,"does not exist"))}
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
