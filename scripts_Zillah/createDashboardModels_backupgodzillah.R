## set environment ##

library(ForestForesight)

get_raster=function(datafolder,date,feature,tile){
  allfiles=list.files(datafolder,recursive=T,pattern=tile,full.names = T)
  allfiles=allfiles[grep("tif$",allfiles)]
  allfiles=allfiles[grep(feature,allfiles)]
  return(ForestForesight::select_files_date(date,allfiles))
}


data("gfw_tiles")
gfw_tiles = vect(gfw_tiles)
data("countries")
countries = vect(countries)
#countries = countries[countries$iso3=="GAB",]
Sys.setenv("xgboost_datafolder" = "D:/ff-dev/results/preprocessed")
groups = unique(countries$group)
dates = daterange("2022-06-01","2023-07-01")
end_date = dates[length(dates)]

exp1_name = "1_year_training"
exp2_name = "max_training"
exp3_name = "max_training_DTH"
exp4_name = "1_year_training_DTH"

for (group in groups[35:46]) {
  tryCatch({
    cat(" starting group ",group, "\n")
    countriessel = countries$iso3[which(countries$group == group)]
    alldata = ff_prep(datafolder = "D:/ff-dev/results/preprocessed/",
                      country = countriessel,start = "2021-01-01",end = end_date,
                      fltr_features = "initialforestcover",fltr_condition = ">0",
                      sample_size = 0.2,verbose = F,shrink = "extract",
                      label_threshold = 1,addxy = F,
                      groundtruth_pattern = "groundtruth6m")
    sel_data = alldata$data_matrix$features[,"monthssince2019"] <= 35
    train_12 =  list(features = alldata$data_matrix$features[sel_data,], label = alldata$data_matrix$label[sel_data])
    dir.create(file.path("D:/ff-dev/predictionsZillah/models/",group))
    model1 = ff_train(train_12,eta = 0.2,gamma = 0.2,min_child_weight = 3,max_depth = 6,nrounds = 100,subsample = 0.3,verbose = T,
                        modelfilename = file.path("D:/ff-dev/predictionsZillah/models/",group,paste0(group,"_",exp1_name,".model")),
                        features = alldata$features)
    rm(sel_data)
    rm(train_12)
    for (dr2 in dates) {
      new_date = round(as.numeric(lubridate::as.period(as.Date(dr2) - as.Date("2019-01-01"),"months"),"months"))
      new_end_date = new_date - 6
      if (!dir.exists(file.path("D:/ff-dev/predictionsZillah/models/",group))) {dir.create(file.path("D:/ff-dev/predictionsZillah/models/",group))}
      sel_data = alldata$data_matrix$features[,"monthssince2019"] <= new_end_date
      train_max =  list(features = alldata$data_matrix$features[sel_data,], label = alldata$data_matrix$label[sel_data])
      model2 = ff_train(train_max,eta = 0.2,gamma = 0.2,
                     min_child_weight = 3,max_depth = 6,nrounds = 100,
                     subsample = 0.3,verbose = T,
                     modelfilename = file.path("D:/ff-dev/predictionsZillah/models/",group,paste0(group,"_",exp2_name,".model")),
                     features = alldata$features)
      rm(sel_data)
      rm(train_max)
      cat("new model is trained")

      sel_data = alldata$data_matrix$features[,"monthssince2019"] == new_end_date
      train_last_month = list(features = alldata$data_matrix$features[sel_data,], label = alldata$data_matrix$label[sel_data])

      #best TH model 1
      prediction_last_month1 = ff_predict(model1,test_matrix = train_last_month,
                                       groundtruth = train_last_month$label,verbose = T)
      print("calculate best threshold 1")
      th1 = bestThreshold(prediction_last_month1$predictions, train_last_month$label)
      print(paste("Model 1: the best threshold for", dr2, "and", group, "is", round(th1$bestThreshold,2), "with an F05 of", round(th1$maxFscore,2)))

      # best th model 2
      prediction_last_month = ff_predict(model2,test_matrix = train_last_month,
                                             groundtruth = train_last_month$label,verbose = T)
      print("calculate best threshold 2")
      th = bestThreshold(prediction_last_month$predictions, train_last_month$label)
      print(paste("Model 2: the best threshold for", dr2, "and", group, "is", round(th$bestThreshold,2), "with an F05 of", round(th$maxFscore,2)))
      rm(sel_data)
      rm(train_last_month)

      for (country in countriessel) {
        cat("starting country ",country)
        tiles = gfw_tiles[countries[countries$iso3 == country],]$tile_id
        for (tile in tiles) {
          cat(" starting tile ",tile,"\n")
          predset = ff_prep(datafolder = "D:/ff-dev/results/preprocessed/",tiles = tile,
                          start = dr2,verbose = F,fltr_features = "initialforestcover",
                          fltr_condition = ">0",addxy = F,label_threshold = 1)
          #          print("predict with best threshold")
          prediction1 = ff_predict(model1,test_matrix = predset$data_matrix,indices = predset$testindices,threshold = 0.5,
                                templateraster = predset$groundtruthraster,groundtruth = predset$groundtruth,verbose = F, certainty = T)
          prediction2 = ff_predict(model2,test_matrix = predset$data_matrix,indices = predset$testindices,threshold = 0.5,
                                 templateraster = predset$groundtruthraster,groundtruth = predset$groundtruth,verbose = F, certainty = T)


          #if(!dir.exists(file.path("D:/ff-dev/results/predictions/",country))){dir.create(file.path("D:/ff-dev/results/predictions/",country))}
          print("analyze")
          forestras=get_raster(tile=tile,date=dr2,datafolder="D:/ff-dev/results/preprocessed/input/",feature="initialforestcover")
          ff_analyze(as.numeric(prediction1$predicted_raster > 0.5),groundtruth = predset$groundtruthraster,
                     csvfile = paste0("D:/ff-dev/predictionsZillah/accuracy_analysis/DBModels/", exp1_name,".csv")
                     ,tile = tile,date = dr2,return_polygons = F,append = T,country = country,verbose = T, method = exp1_name,forestmask = forestras)

          ff_analyze(as.numeric(prediction2$predicted_raster > 0.5),groundtruth = predset$groundtruthraster,
                     csvfile = paste0("D:/ff-dev/predictionsZillah/accuracy_analysis/DBModels/", exp2_name,"2.csv")
                     ,tile = tile,date = dr2,return_polygons = F,append = T,country = country,verbose = T, method = exp2_name,forestmask = forestras)

          ff_analyze(as.numeric(prediction2$predicted_raster > th$bestThreshold),groundtruth = predset$groundtruthraster,
                     csvfile = paste0("D:/ff-dev/predictionsZillah/accuracy_analysis/DBModels/", exp3_name,".csv")
                     ,tile = tile,date = dr2,return_polygons = F,append = T,country = country,verbose = T, method = exp3_name,forestmask = forestras)

          ff_analyze(as.numeric(prediction1$predicted_raster > th1$bestThreshold),groundtruth = predset$groundtruthraster,
                     csvfile = paste0("D:/ff-dev/predictionsZillah/accuracy_analysis/DBModels/", exp4_name,".csv")
                     ,tile = tile,date = dr2,return_polygons = F,append = T,country = country,verbose = T, method = exp4_name,forestmask = forestras)
        }
      }

    }}, error = function(e) {
      cat("Error occurred:", conditionMessage(e), "\n")})}
