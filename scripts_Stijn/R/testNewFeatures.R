## SURINAME ##

library(ForestForesight)

country = "SUR"
model_path = "D:/temp/ResultsStijn/surinameModel.model"
exp_name = "default_run"

# Get the data
train_data = ff_prep(country = country,
                     datafolder = "D:/ff-dev/results/preprocessed" ,
                     start = "2021-01-01",
                     end = "2021-12-01",
                     sample_size = 0.3,
                     shrink = "extract",
                     fltr_features = "initialforestcover",
                     fltr_condition = ">0",
                     label_threshold = 1)

# get correlations
library(corrplot)
sur_combined = cbind(train_data$data_matrix$label, train_data$data_matrix$features)
colnames(sur_combined)[1] = "groundtruth"
M = cor(sur_combined, use = "everything")
testRes = cor.mtest(sur_combined, conf.level = 0.5)

png("D:/temp/ResultsStijn/corrplotSUR2021.png", width = 1950, height = 1950)
corrplot(M, p.mat = testRes$p, method = 'circle', type = 'lower', insig = 'blank',
         addCoef.col = 'black',tl.cex = 1.2,tl.col = "black", number.cex = 0.9, diag = FALSE)
dev.off()

# Train the model
surinameModel = ff_train(train_data$data_matrix, verbose = T,
                         modelfilename = model_path,
                         features = train_data$features)


# Importance matrix #
png(paste0("D:/temp/ResultsStijn/importance_matrix", country,".png"), width = 800, height = 1800)
importance_matrix <- xgb.importance(model = surinameModel)
print(importance_matrix)
xgb.plot.importance(importance_matrix = importance_matrix, cex = 1.5, left_margin = 16)
dev.off()


# SHAP #
library("SHAPforxgboost")
shap_sample = train_data$data_matrix$features[sample(nrow(train_data$data_matrix$features), 1000),]
shap_values = shap.values(xgb_model = surinameModel, X_train = shap_sample)
# The ranked features by mean |SHAP|
shap_values$mean_shap_score
# To prepare the long-format data:
shap_long <- shap.prep(xgb_model = surinameModel, X_train = shap_sample)
# **SHAP summary plot**

library("ggplot2")
png("D:/temp/ResultsStijn/shapplotLaos.png", width = 800, height = 1800)
shap.plot.summary(shap_long) +
  ggplot2::theme(text = element_text(size = 18), legend.text = element_text(size = 12))
dev.off()

# get the tiles
data(gfw_tiles)
data("countries")
countries <- terra::vect(countries)
shape <- countries[which(countries$iso3 == country),]
tiles = terra::vect(gfw_tiles)[shape,]$tile_id

# loop over the tiles to get the predictions

dates = daterange("2022-06-01","2023-06-01")
for (date in dates){
  raslist <- list()
  for (tile in tiles) {
    #run the predict function if a model was not built but was provided by the function

    predset <- ff_prep(datafolder = "D:/ff-dev/results/preprocessed" , tiles = tile,
                       start = date,
                       verbose = T, fltr_features = "initialforestcover",
                       fltr_condition = ">0",
                       label_threshold = 1)

    prediction <- ff_predict(model = surinameModel, test_matrix = predset$data_matrix,
                             indices = predset$testindices,
                             templateraster = predset$groundtruthraster,
                             verbose = T,certainty = T, groundtruth = predset$data_matrix$label)
    plot(prediction$predicted_raster)
    plot(prediction$predicted_raster > 0.5)
    
    print(paste(tile, ": precision =", round(prediction$precision,2), 
                ", recall=", round(prediction$recall,2),
                ",F0.5-score=", round(predictions$F0.5,2)))
    

    raslist[[tile]] <- prediction$predicted_raster
    # Analyze prediction
    forestras = get_raster(tile = tile, date = date, datafolder = "D:/ff-dev/results/preprocessed/input/",
                           feature = "initialforestcover")
    plot(rast(forestras))
    ff_analyze(prediction$predicted_raster > 0.5, groundtruth = predset$groundtruthraster,
               csvfile = paste0("D:/temp/ResultsStijn/accuracy_analysis/", exp_name, ".csv"), tile = tile, date = date,
               return_polygons = FALSE, append = TRUE, country = country,
               verbose = T, forestmask = forestras)
  }
  if (length(raslist) == 1) {fullras <- raslist[[1]]}else{
    fullras <- do.call(terra::merge,unname(raslist))
  }
  fullras <- terra::mask(fullras,shape)
  fullras <- terra::crop(fullras,shape)
  plot(fullras > 0.5)
}

#nog toevoegen 




