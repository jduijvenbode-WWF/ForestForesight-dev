## set environment ##

library(ForestForesight)
data("gfw_tiles")
gfw_tiles = vect(gfw_tiles)
data("countries")
countries = vect(countries)
Sys.setenv("xgboost_datafolder" = "D:/ff-dev/results/preprocessed")
groups = unique(countries$group)
dates = daterange("2023-06-01", "2023-12-01")
exp_name = "pred_amounts_all"

for (group in "Brazil"){
  tryCatch({
    countriessel = countries$iso3[which(countries$group == group)]
    if (file.exists(file.path("D:/ff-dev/predictionsZillah/models",group,paste0(group,"_",exp_name,".model")))){
      model_amounts = file.path("D:/ff-dev/predictionsZillah/models",group,paste0(group,"_",exp_name,".model"))
      cat("Using trained model for ", group , '\n')
    } else{
      cat("Training a new model for ", group, "\n")
      traindata = ff_prep(datafolder = "D:/ff-dev/results/preprocessed/",
                          country = countriessel,start = "2022-01-01",end = "2022-12-01",
                          fltr_features = c("initialforestcover"),fltr_condition = c(">0"),
                          sample_size = 0.1,verbose = F,shrink = "extract",
                          label_threshold = NA,addxy = F,
                          groundtruth_pattern = "groundtruth6m", validation_sample = 0.2)
      model_amounts = ff_train(traindata$data_matrix,traindata$validation_matrix,eta = 0.2,gamma = 0.2,
                               min_child_weight = 3,max_depth = 6,nrounds = 500,
                               subsample = 0.3,verbose = F,
                               modelfilename = file.path("D:/ff-dev/predictionsZillah/models",group,paste0(group,"_",exp_name,".model")),
                               features = traindata$features,eval_metric = "rmse", objective = "reg:squarederror")
    }

    for (date in dates) {
      for (country in countriessel) {
        if (!dir.exists(file.path("D:/ff-dev/predictionsZillah/amountPred/",country))) {dir.create(file.path("D:/ff-dev/predictionsZillah/amountPred/",country))}
        cat("starting predictions for country ",country, "and date ", date, "\n")
        tiles = gfw_tiles[countries[countries$iso3 == country],]$tile_id
        raslist <- list()
        for (tile in tiles) {
          cat(group,"group: ", which(groups == group), "from", length(groups), '\n',
              country, "country: ", which(country == countriessel),"from", length(countriessel), '\n',
              date, "date: ", which(dates == date), "from", length(dates), '\n',
              tile, "tile: ", which(tiles == tile), "from", length(tiles), '\n')
          predset = ff_prep(datafolder = "D:/ff-dev/results/preprocessed/",tiles = tile,
                            start = date,verbose = F,addxy = F,label_threshold = NA)
          max_def = 1600 - predset$data_matrix$features[,"totallossalerts"]
          no_def = predset$data_matrix$features[,"initialforestcover"] == 0
          templateraster = predset$groundtruthraster
          templateraster[] = max_def
          no_def_rast = predset$groundtruthraster
          no_def_rast[] = no_def

          # Predict the amount of deforestation
          prediction_amounts_test = ff_predict(model_amounts,test_matrix = predset$data_matrix,threshold = NA,
                                               templateraster = predset$groundtruthraster,verbose = F, certainty = T)
          predicted_raster <- prediction_amounts_test$predicted_raster
          predicted_raster[no_def_rast] = 0
          # Set negative values to 0
          predicted_raster[predicted_raster < 0] <- 0
          ## ADJUST USING REMAINING FOREST ! ##
          predicted_raster = min(predicted_raster, templateraster)

          raslist[[tile]] <- predicted_raster # add prediction to the list
          print(paste("Correlation :", round(cor(predicted_raster[],predset$groundtruthraster[], use = "complete.obs"),2)))
         # forestras=get_raster(tile = tile,date = date,datafolder = "D:/ff-dev/results/preprocessed/input/",feature="initialforestcover")
         # ff_analyze_amounts(predicted_raster ,groundtruth = predset$groundtruthraster,
          #                   csvfile = paste0("D:/ff-dev/predictionsZillah/accuracy_analysis/", exp_name,"onlybinpred.csv")
           #                  ,tile = tile,date = date,return_polygons = F,append = T,country = country,verbose = T,
            #                 method = exp_name)

        }

        # combine the rasters to get one raster for the whole country
        if (length(raslist) == 1) {fullras <- raslist[[1]]}else{
          fullras <- do.call(terra::merge,unname(raslist))
        }
        shape <- countries[which(countries$iso3 == country),]
        fullras <- terra::mask(fullras,shape)
        fullras <- terra::crop(fullras,shape)
        writeRaster(fullras, paste0("D:/ff-dev/predictionsZillah/amountPred/", country,'/', country ,'_', date, "_amountPrediction.tif"), overwrite = T )


      }

    }}, error = function(e) {
      cat("Error occurred:", conditionMessage(e), "\n")})}
