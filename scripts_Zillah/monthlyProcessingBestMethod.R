library(ForestForesight)
data(countries)
countrynames=countries$iso3
ff_folder= "D:/ff-dev/results"

# get first day of the current month
proc_date = as.Date(paste(format(Sys.Date(), "%Y"), format(Sys.Date(), "%m"), "01", sep = "-"))

# get the best method per country
best_method_data =  read.csv("D:/ff-dev/results/accuracy_analysis/resultaten_202405/result/bestmethods.csv")
library(dplyr)
unique_method <- best_method_data %>%
  distinct(group, method)
rm(best_method_data)
new_models = c()
for(x in seq(76,length(countrynames))){
  country <- countrynames[x]
  group = countries$group[x]
  method = unique_method$method[unique_method==group]
  if(length(method)==0){method="lastYear_training"}
  cat(paste("processing",country,"using method ",method, "\n"))
  setwd("D:/ff-dev/results/predictions/")
  if(!dir.exists(country)){dir.create(country)}
  setwd(country)
  if(!file.exists(paste0(country,"_",proc_date,".tif"))){
    cat(paste("processing",country,"for",proc_date,"\n"))
    shape <- terra::vect(countries)[which(countries$iso3 == country),]

    # 1 year training or new country group model already trained
    if (grepl("1_year_training", method)|| any(new_models==group)){
      cat("Existing model will be used \n")
      modelpath=file.path(ff_folder,"models",group,paste0(group,".model"))
      if(!file.exists(modelpath)){stop(paste(modelpath,"does not exist"))}
      tryCatch({
        b <- train_predict_raster(shape = shape,
                                  prediction_date = proc_date,
                                  ff_folder = ff_folder,
                                  verbose = TRUE,
                                  model = modelpath,
                                  model_path = modelpath,
                                  label_threshold = 1)
        terra::writeRaster(b,paste0(country,"_",proc_date,".tif"),overwrite = T)
      }, error = function(e) {
        # Print the error message
        print(paste("An error occurred:", e))
        # Continue the loop or execute other code as needed
      })
    } else{ # new model needs to be trained
      # last year training
      if (grepl("lastYear_training", method)){
        train_start= proc_date %m-% months(12)
        train_end= proc_date %m-% months(6)
      }
      # max training
      if (grepl("max_training", method)){
        train_start= "2021-01-01"
        train_end= proc_date %m-% months(6)
      }
      modelpath=file.path(ff_folder,"models",group,paste0(group,".model"))
      tryCatch({
        b <- train_predict_raster(shape = shape,
                                  train_start = train_start,
                                  train_end= train_end,
                                  prediction_date = proc_date,
                                  ff_folder = ff_folder,
                                  verbose = TRUE,
                                  model_path = modelpath,
                                  label_threshold = 1)
        new_models = c(new_models, group)
        terra::writeRaster(b,paste0(country,"_",proc_date,".tif"),overwrite = T)
      }, error = function(e) {
        # Print the error message
        print(paste("An error occurred:", e))
        # Continue the loop or execute other code as needed
      })

    }




  }
}
