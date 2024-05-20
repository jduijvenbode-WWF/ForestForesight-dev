library(ForestForesight)
library(sf)
data(countries)
ff_folder = "D:/ff-dev/results"
countrynames = countries$iso3
proc_dates = rev(as.character(daterange("2023-06-01","2024-05-01")))
for (gt_month in c("1m", "3m","12m")) {
  for (proc_date in proc_dates) {
    for (x in seq(length(countrynames))) {
      country <- countrynames[x]
      setwd("D:/ff-dev/predictionsZillah/predictions/")
      if (!dir.exists(country)) {dir.create(country)}
      setwd(country)
      if (!file.exists(paste0(country,"_",proc_date,"_", gt_month,".tif"))) {
        cat(paste("processing",country,"for",proc_date, "and", gt_month,"\n"))
        shape <- terra::vect(countries)[which(countries$iso3 == country),]
        modelfolder = file.path(paste0("D:/ff-dev/predictionsZillah/models_", gt_month))
        if (!dir.exists(modelfolder)) {dir.create(modelfolder)}
        tryCatch({
          b <- train_predict_raster(country = country,
                                    prediction_date = proc_date,
                                    ff_folder = ff_folder,
                                    train_start = "2022-01-01",
                                    train_end = "2022-12-01",
                                    verbose = TRUE,
                                    groundtruth_pattern = paste0("groundtruth",gt_month),
                                    model_folder = modelfolder,
                                    accuracy_csv = paste0("D:/ff-dev/predictionsZillah/accuracy_analysis/2ndYearTraining_", gt_month,".csv"))
          terra::writeRaster(b,paste0(country,"_",proc_date,"_",gt_month,".tif"),overwrite = T)
        }, error = function(e) {
          # Print the error message
          print(paste("An error occurred:", e))
          # Continue the loop or execute other code as needed
        })

      }
    }
  }
}

