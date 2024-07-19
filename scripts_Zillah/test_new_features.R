library(ForestForesight)
data(countries)
countries <- terra::vect(countries)
data(gfw_tiles)
countrynames = countries$iso3
ff_folder = "D:/ff-dev/results"

dates = daterange("2023-06-01","2023-12-01")
groups = unique(countries$group)[1:7]

for (group in groups){
  sel_countries = countries$iso3[countries$group == group]
  # train A model on 2022 with all features
  traindata_all <- ff_prep(datafolder = "D:/ff-dev/results/preprocessed",
                       country = sel_countries ,
                       start = "2022-01-01",
                       end = "2022-12-01" ,
                       fltr_condition = ">0",
                       fltr_features = "initialforestcover",
                       sample_size = 0.2,
                       shrink = "extract",
                       label_threshold = 1)
  model_all =  ff_train( traindata_all$data_matrix,
                                modelfilename = paste0( "D:/ff-dev/predictionsZillah/models_2022/",group,"_all.model"), # where to save the model
                                features = traindata_all$features)

  # Train A model on 2022 excluding new features
  exc_features = c("aridityannual","ariditydriestquarter","cattlesmoothed",
                   "closenesstocattleabove10000", "closenesstocattleabove2000",
                   "closenesstococoa" ,"closenesstocoffee",
                   "closenesstocropland", "closenesstofiber",
                   "closenesstoforestedge","closenesstomennonitest",
                   "closenesstomining","closenesstooilpalm",
                   "closenesstorice", "closenesstorubber","closenesstosoybean",
                   "croplandcapacity100p","croplandcapacitybelow50p",
                   "croplandcapacityover50p","diminishinghotspot",
                   "dpicoal","dpiconvgas","dpiconvoil","dpihydro",
                   "dpimetallicmining","dpinonmetallicmining",
                   "dpiunconvgas","fwi","intensifyinghotspot",
                   "mennonitessmoothed", "miningsmoothed",
                   "newhotspot","palmoilmills", "persistanthotspot",
                   "soybeansmoothed","sporadichotspot")
  traindata_exc_features = list()
  traindata_exc_features$data_matrix$features = traindata_all$data_matrix$features[,!colnames(traindata_all$data_matrix$features) %in% exc_features]
  traindata_exc_features$data_matrix$label = traindata_all$data_matrix$label
  traindata_exc_features$features = colnames(traindata_exc_features$data_matrix$features)
  model_exc =  ff_train(traindata_exc_features$data_matrix,
                         modelfilename = paste0( "D:/ff-dev/predictionsZillah/models_2022/",group,"_exc.model"), # where to save the model
                         features = traindata_exc_features$features)
  for (country in sel_countries) {
    shape <- terra::vect(countries)[which(countries$iso3 == country),]
    tiles <- terra::vect(gfw_tiles)[shape,]$tile_id
    for (date in dates) {
      for (tile in tiles){
        # get test data
        predset_all <- ff_prep(datafolder = "D:/ff-dev/results/preprocessed",
                           tiles = tile,
                           start = date,
                           fltr_features = "initialforestcover",
                           fltr_condition = ">0",
                           label_threshold = 1)
        predset_exc_features = list()
        predset_exc_features$data_matrix$features = predset_all$data_matrix$features[,!colnames(predset_all$data_matrix$features) %in% exc_features]
        predset_exc_features$data_matrix$label = predset_all$data_matrix$label

      # predict raster for model with all features
        prediction_all <- ff_predict(model = model_all,
                                 test_matrix = predset_all$data_matrix,
                                 indices = predset_all$testindices,
                                 groundtruth = predset_all$data_matrix$label,
                                 templateraster = predset_all$groundtruthraster,
                                 certainty = T)
      # predict raster for model with new features excluded
        prediction_exc <- ff_predict(model = model_exc,
                                   test_matrix = predset_exc_features$data_matrix,
                                   indices = predset_all$testindices,
                                   groundtruth = predset_all$data_matrix$label,
                                   templateraster = predset_all$groundtruthraster,
                                   certainty = T)
        forestras = get_raster(tile = tile,
                               date = date,
                               datafolder = paste0("D:/ff-dev/results/preprocessed/input/"),
                               feature = "initialforestcover")

        ff_analyze(prediction_all$predicted_raster > 0.5, # the predictions with a treshold of 0.5
                   groundtruth = predset_all$groundtruthraster,
                   csvfile = "D:/ff-dev/predictionsZillah/accuracy_analysis/2022_features/2022_all.csv",
                   tile = tile,
                   date = date,
                   return_polygons = FALSE,
                   append = TRUE,
                   country = country,
                   forestmask = forestras,
                   method = "train2022_all")
        ff_analyze(prediction_exc$predicted_raster > 0.5, # the predictions with a treshold of 0.5
                   groundtruth = predset_all$groundtruthraster,
                   csvfile = "D:/ff-dev/predictionsZillah/accuracy_analysis/2022_features/2022_exc.csv",
                   tile = tile,
                   date = date,
                   return_polygons = FALSE,
                   append = TRUE,
                   country = country,
                   forestmask = forestras,
                   method = "train2022_exc")

    }}
  }
}
