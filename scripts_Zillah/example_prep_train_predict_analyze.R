
# This scripts provides an example on how to use:
# 1) ff_prep(), to prepare the data.
# 2) ff_train(), to train a model.
# 3) ff_predict(), to predict deforestation using a model.
# 4) ff_analyze(), to analyze the results


# Install the package if it is not yet installed
# devtools::install_github("jduijvenbode-WWF/ForestForesight")
library(ForestForesight)

# load data
data("countries")

# Gabon will be used as an example country
country ="GAB" # use iso3 country code

## 1 ff_prep ##
traindata <- ff_prep(datafolder = "D:/ff-dev/results/preprocessed",
                     country= country ,
                     start = "2021-01-01",
                     end = "2021-12-01" ,
                     fltr_condition = ">0",
                     fltr_features = "initialforestcover", # only select pixels with a forest cover above 0
                     sample_size = 0.3,
                     shrink = "extract",
                     label_threshold = 1)

## 2 ff_train ##
model <- ff_train(traindata$data_matrix,
                  modelfilename = "D:/ff-dev/results/GabonExampleModel.model", # where to save the model
                  features = traindata$features)

## 3 ff_predict and ff_analyze ## NOTE CHECK PRECISION AND RECALL AND FO5

# Here we will loop over all tiles of the country to predict and analyze the data from the whole country

data(gfw_tiles,envir = environment()) # get the tiles data
countries <- terra::vect(countries)
shape <- countries[which(countries$iso3 == country),] # get shape of country
tiles <- terra::vect(gfw_tiles)[shape,]$tile_id # select tiles based on shape
raslist <- list() #initialize an empty list for the prediction rasters

# note : to predict over multiple dates add a for-loop of dates using daterange()
prediction_date = "2023-01-01"
for (tile in tiles) {
  # first ff_prep is used to obtain the data to predict/ test on
  # We want predictions for the whole area so no sample is taken
   predset <- ff_prep(datafolder = "D:/ff-dev/results/preprocessed",
                      tiles = tile,
                      start = prediction_date,
                      fltr_features = "initialforestcover",
                      fltr_condition = ">0",
                      label_threshold = 1)

  prediction <- ff_predict(model = model,
                           test_matrix = predset$data_matrix,
                           indices = predset$testindices,
                           groundtruth = predset$data_matrix$label,
                           templateraster = predset$groundtruthraster,
                           certainty = T)
  # you can print the scores per tile
  print(paste(tile, ": precision =", round(prediction$precision,2),
              ", recall= ", round(prediction$recall,2),
              ", F0.5-score =", round(prediction$F0.5,2)))

  raslist[[tile]] <- prediction$predicted_raster # add prediction to the list


  # Analyze prediction
  # If you only want to analyze within the forest mask, use get raster to get the forest cover.
  forestras = get_raster(tile = tile,
                         date = prediction_date,
                         datafolder = paste0("D:/ff-dev/results/preprocessed/input/"),
                         feature = "initialforestcover")

  ff_analyze(prediction$predicted_raster > 0.5, # the predictions with a treshold of 0.5
             groundtruth = predset$groundtruthraster,
             csvfile = "D:/ff-dev/results/accuracy_analysis/example_Gabon.csv",
             tile = tile,
             date = prediction_date,
             return_polygons = FALSE,
             append = TRUE,
             country = country,
             forestmask = forestras,
             method = "train2021")
}

# You can combine the rasters now to get one raster for the whole country
if (length(raslist) == 1) {fullras <- raslist[[1]]}else{
  fullras <- do.call(terra::merge,unname(raslist))
}
fullras <- terra::mask(fullras,shape)
fullras <- terra::crop(fullras,shape)

# plot the prediction with a threshold of 0.5
plot(fullras>0.5)




