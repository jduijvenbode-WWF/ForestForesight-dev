## set environment ##

library(ForestForesight)
data("gfw_tiles")
gfw_tiles = vect(gfw_tiles)
data("countries")
countries = vect(countries)
Sys.setenv("xgboost_datafolder" = "D:/ff-dev/results/preprocessed")
groups = unique(countries$group)
dates = daterange("2022-06-01","2023-07-01")
exp_name = "pred_amounts"

for (group in groups) {
  tryCatch({
    if (!dir.exists(file.path("D:/ff-dev/predictionsZillah/models/",group))) {dir.create(file.path("D:/ff-dev/predictionsZillah/models/",group))}
     cat(" starting group",group, "\n")
    countriessel = countries$iso3[which(countries$group == group)]
    if (file.exists(file.path("D:/ff-dev/predictionsZillah/models",group,paste0(group,"_",exp_name,".model")))){
      model_amounts = file.path("D:/ff-dev/predictionsZillah/models",group,paste0(group,"_",exp_name,".model"))
    } else{
      traindata = ff_prep(datafolder = "D:/ff-dev/results/preprocessed/",
                          country = countriessel,start = "2021-01-01",end = "2021-12-01",
                          fltr_features = c("groundtruth6m","initialforestcover"),fltr_condition = c(">0",">0"),
                          sample_size = 1,verbose = F,shrink = "extract",
                          label_threshold = NA,addxy = F,
                          groundtruth_pattern = "groundtruth6m", validation_sample = 0.2)
      model_amounts = ff_train(traindata$data_matrix,traindata$validation_matrix,eta = 0.2,gamma = 0.2,
                               min_child_weight = 3,max_depth = 6,nrounds = 500,
                               subsample = 0.3,verbose = F,
                               modelfilename = file.path("D:/ff-dev/predictionsZillah/models",group,paste0(group,"_",exp_name,".model")),
                               features = traindata$features,eval_metric = "rmse", objective = "reg:squarederror")
    }

    for (date in dates){
      for (country in countriessel) {
        if (!dir.exists(file.path("D:/ff-dev/predictionsZillah/amountPred/",country))) {dir.create(file.path("D:/ff-dev/predictionsZillah/amountPred/",country))}
        cat("starting country ",country)
        tiles = gfw_tiles[countries[countries$iso3 == country],]$tile_id
        for (tile in tiles) {
          cat(" starting tile ",tile,"\n")
          predset = ff_prep(datafolder = "D:/ff-dev/results/preprocessed/",tiles = tile,
                            start = date,verbose = F,addxy = F,label_threshold = NA)
          max_def = 1600 - predset$data_matrix$features[,"totallossalerts"]
          templateraster = predset$groundtruthraster
          templateraster[] =max_def


          # Predict if deforestation will happen
          defPred =  rast(paste0("D:/ff-dev/results/predictions/", tile,"/", tile, "_", date,"_predictions.tif"))>50
          # select data where deforestation is predicted
          predset$data_matrix$label=predset$data_matrix$label[defPred[]]
          predset$data_matrix$features=predset$data_matrix$features[defPred[],]
          # Predict the amount of deforestation
          prediction_amounts_test = ff_predict(model_amounts,test_matrix = predset$data_matrix,indices = which(values(defPred)),threshold = NA,
                                           templateraster = predset$groundtruthraster,verbose = F, certainty = T)
          predicted_raster <- prediction_amounts_test$predicted_raster
          predicted_raster[!defPred]=NA
          # Set negative values to 0
          predicted_raster[predicted_raster < 0] <- 0

          ## ADJUST USING REMAINING FOREST ! ##
          predicted_raster = min(predicted_raster, templateraster)
          print(paste("Correlation :", cor(predicted_raster[],predset$groundtruthraster[], use="complete.obs")))
          writeRaster(predicted_raster, paste0("D:/ff-dev/predictionsZillah/amountPred/", country,'/', tile,'_', date, "_amountPrediction.tif"), overwrite=T )
          # forestras=get_raster(tile = tile,date = date,datafolder = "D:/ff-dev/results/preprocessed/input/",feature="initialforestcover")
          ff_analyze_amounts(predicted_raster ,groundtruth = predset$groundtruthraster,
                     csvfile = paste0("D:/ff-dev/predictionsZillah/accuracy_analysis/", exp_name,"onlybinpred.csv")
                     ,tile = tile,date = date,return_polygons = F,append = T,country = country,verbose = T,
                     method = exp_name)

          }
      }

    }}, error = function(e) {
      cat("Error occurred:", conditionMessage(e), "\n")})}
