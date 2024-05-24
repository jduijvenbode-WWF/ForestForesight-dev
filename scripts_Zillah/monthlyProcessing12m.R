library(ForestForesight)
library(sf)
data(countries)
ff_folder = "D:/ff-dev/results"
countrynames = unique(countries$group)
proc_dates = as.character(daterange("2023-01-01","2023-04-01"))
for (gt_month in c("12m")) {
  for (proc_date in proc_dates) {
    for (x in seq(length(countrynames))) {
      country <- countrynames[x]
      setwd("D:/ff-dev/predictionsZillah/predictions/")
      if (!dir.exists(country)) {dir.create(country)}
      setwd(country)
      if (!file.exists(paste0(country,"_",proc_date,"_", gt_month,".tif"))) {
        cat(paste("processing",country,"for",proc_date, "and", gt_month,"\n"))
        shape <- terra::aggregate(terra::vect(countries)[which(countries$group == country),])
        modelname = paste0("D:/ff-dev/predictionsZillah/models_", gt_month,"/",country,"_", gt_month,".model" )
        if (!dir.exists(dirname(modelname))) {dir.create(dirname(modelname))}
        tryCatch({
          if (!file.exists(modelname)){
            b <- ForestForesight::train_predict_raster(shape = shape ,
                                                       prediction_date = proc_date,
                                                       ff_folder = ff_folder,
                                                       train_start = "2021-01-01",
                                                       train_end = "2021-12-01",
                                                       verbose = TRUE,
                                                       groundtruth_pattern = paste0("groundtruth",gt_month),
                                                       model_path = modelname,
                                                       accuracy_csv = paste0("D:/ff-dev/predictionsZillah/accuracy_analysis/2ndYearTraining_", gt_month,".csv"))
          }else{
            b <- ForestForesight::train_predict_raster(shape = shape ,
                                                       prediction_date = proc_date,
                                                       model = modelname,
                                                       ff_folder = ff_folder,
                                                       verbose = TRUE,
                                                       model_path = modelname,
                                                       groundtruth_pattern = paste0("groundtruth",gt_month),
                                                       accuracy_csv = paste0("D:/ff-dev/predictionsZillah/accuracy_analysis/2ndYearTraining_", gt_month,".csv"))
          }

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

