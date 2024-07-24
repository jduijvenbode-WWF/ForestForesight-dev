
# This scripts provides an example on how to use:
#
# 1) ff_dqc(), to check the data quality
# 2) ff_prep(), to prepare the data.
# 3) ff_train(), to train a model.
# 4) ff_predict(), to predict deforestation using a model.
# 5) ff_analyze(), to analyze the results


# Install the package if it is not yet installed
# devtools::install_github("jduijvenbode-WWF/ForestForesight")
library(ForestForesight)

# Set variables
dir_ff = "D:/ff-dev/results" # Change to the directory containing the ff files
threshold = 0.5 # When the model output exceeds this threshold, deforestation will be predicted

# load data
data("countries")
countries <- terra::vect(countries)
data(gfw_tiles,envir = environment()) # get the tiles data

# Gabon will be used as an example country
country = "GAB" # use iso3 country code
shape <- countries[which(countries$iso3 == country),] # get shape of country
tiles <- terra::vect(gfw_tiles)[shape,]$tile_id # select tiles based on shape


## 1 ff_dqc ##
# For this example we will use one of the tiles to check the data quality
dqc_dir = file.path(dir_ff,"preprocessed","input",tiles[2])
data_quality = ff_dqc(folder_path = dqc_dir, # The path to the folder containing TIF files.
                      return_values = T) # Should the values of the rasters also be returned.
print(attributes(data_quality))

# Check if the extent is equal for all layers (or at least for whole 5 degrees)
# Check if there are no doubles (meaning the same feature for the same tile for the same month)
# Evaluate whether the coordinate system is similar for all files (and WGS84) and if the resolution is the same


## 2 ff_prep ##
traindata <- ff_prep(
  datafolder = file.path(dir_ff, "preprocessed"), # Path to the data folder
  # You can obtain the data either per country, per tile, or for another shape (spatvector)
  # In this case we will use country
  country = country,       # Country or countries for which the data is prepared
  shape = NA,              # SpatVector for which the data is prepared
  tiles = NULL,            # Vector of tiles in the syntax of e.g. 10N_080W
  groundtruth_pattern = "groundtruth6m",  # Pattern to identify ground truth files
  start = "2021-01-01",    # Start date for training data in the format "YYYY-MM-DD"
  end = "2021-12-01",      # End date for training data in the format "YYYY-MM-DD"
  inc_features = NA,       # Vector of included features
  exc_features = NA,       # Vector of excluded features
  fltr_features = "initialforestcover", # Only select pixels with a forest cover above 0
  fltr_condition = ">0",   # Vector of filtering conditions
  validation_sample = 0,   # Float indicating how much of the dataset should be used for validation
  sample_size = 0.3,       # Fraction size of the random sample
  adddate = TRUE,          # Boolean indicating whether the date is relative
  sampleraster = TRUE,     # Boolean indicating if sampling raster should be used
  verbose = FALSE,         # Boolean indicating whether to print progress messages
  shrink = "extract",      # Option to shrink the input area if a country was selected
  window = NA,             # Set the extent on which to process
  label_threshold = 1,     # Threshold for labeling
  addxy = FALSE            # Boolean indicating whether to add xy coordinates
)

## 3 ff_train ##
model <- ff_train(
  train_matrix = traindata$data_matrix, # The training matrix for XGBoost. Should be of type xgb.Dmatrix
  modelfilename = file.path(dir_ff, paste0(country, "ExampleModel.model")), # Where to save the model. Should end with the extension model
  features = traindata$features, # Vector with the feature names of the training dataset
  validation_matrix = NA, # The validation matrix for XGBoost. Should be of type xgb.Dmatrix
  nrounds = 200, # Number of boosting rounds. Default is 200
  eta = 0.1, # Learning rate. Default is 0.1
  max_depth = 5, # Maximum tree depth. Default is 5
  subsample = 0.75, # Subsample ratio of the training instances. Default is 0.75
  eval_metric = "aucpr", # Evaluation metric. Default is "aucpr"
  early_stopping_rounds = 10, # Early stopping rounds. Default is 10
  gamma = NULL, # The gamma value, should be between 0 and 0.3. Determines level of pruning
  min_child_weight = 1, # The minimum weight of the child, determines how quickly the tree grows
  maximize = NULL, # Should be True or False in case a custom evaluation metric is used
  verbose = TRUE, # Should the model run verbose. Default is FALSE
  xgb_model = NULL, # Previous build model to continue the training from
  objective = "binary:logistic" # Specify the learning task and the corresponding learning objective. Default is "binary:logistic"
)

## 4 ff_predict and ff_analyze ##

# Here we will loop over all tiles of the country to predict and analyze the data from the whole country

raslist <- list() #initialize an empty list for the prediction rasters

# note : to predict over multiple dates add a for-loop of dates using daterange()
prediction_date = "2023-01-01"
for (tile in tiles) {
  # first ff_prep is used to obtain the data to predict/ test on
  # We want predictions for the whole area so no sample is taken
  # See the previous use of ff_prep for other possible arguments.
  predset <- ff_prep(datafolder = file.path(dir_ff,"preprocessed"),
                      tiles = tile,
                      start = prediction_date,
                      fltr_features = "initialforestcover",
                      fltr_condition = ">0",
                      label_threshold = 1)

  prediction <- ff_predict(
    model = model,                  # The trained XGBoost model
    test_matrix = predset$data_matrix, # The xgb.DMatrix test matrix
    threshold = threshold,          # Vector with chosen threshold(s). Default is 0.5, which has shown to be the best in almost all scenarios
    groundtruth = predset$data_matrix$label, # A vector of the same length as the test matrix to verify against
    indices = predset$testindices,  # A vector of the indices of the template raster that need to be filled in
    templateraster = predset$groundtruthraster, # A SpatRaster that can serve as the template to fill in the predictions
    verbose = TRUE,                # Whether the output should be verbose
    certainty = TRUE                # If TRUE, the certainty in percentage of the prediction will be returned, otherwise just true or false
  )

  # you can print the scores per tile
  print(paste(tile, ": precision =", round(prediction$precision,2),
              ", recall= ", round(prediction$recall,2),
              ", F0.5-score =", round(prediction$F0.5,2)))

  raslist[[tile]] <- prediction$predicted_raster # add prediction to the list


  ## 5 Analyze prediction using ff_prep ##
  # If you only want to analyze within the forest mask, use get raster to get the forest cover.
  forestras <- get_raster(
    datafolder = file.path(dir_ff, "/preprocessed/input"), # A character string specifying the path to the data folder where raster files are stored
    date = prediction_date, # A Date object representing the date for which raster files are to be retrieved
    feature = "initialforestcover", # A character string specifying the feature of interest to filter raster files
    tile = tile # A character string specifying the pattern to filter specific tiles of raster files
  )


  ff_analyze(
    predictions = prediction$predicted_raster > threshold, # The predictions with the previously defined threshold
    groundtruth = predset$groundtruthraster, # A character vector or raster object representing the ground truth
    csvfile = file.path(dir_ff, "accuracy_analysis/example_Gabon.csv"), # An optional CSV file to which the results will be written
    tile = tile, # A character string specifying the tile.
    date = prediction_date, # A character string representing the date.
    return_polygons = FALSE, # Logical. If TRUE, the polygons with calculated scores will be returned
    append = TRUE, # Logical. If TRUE, results will be appended to the existing CSV file
    country = country, # Character. If NULL, all overlapping polygons will be processed. Otherwise, the ISO3 code should be given
    forestmask = forestras, # An optional character vector or raster object representing the forest mask
    method = "train2022" # Character. The shorthand for the method used, which should also be included in the separate CSV file for storing methods
  )
}

# You can combine the rasters now to get one raster for the whole country
if (length(raslist) == 1) {fullras <- raslist[[1]]}else{
  fullras <- do.call(terra::merge,unname(raslist))
}
fullras <- terra::mask(fullras,shape)
fullras <- terra::crop(fullras,shape)

# plot the prediction with the previous defined threshold
plot(fullras > threshold)




