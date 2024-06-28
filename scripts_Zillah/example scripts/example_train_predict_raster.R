
# Train_predict_raster:
# 1 Either trains a model using training data or uses a pre-trained model
# 2 Predicts the deforestation raster values using the trained model
# 3 If desired saves the accuracy metrics in CSV format

# This scripts provides an example on how to use train_predict_raster.R

# Install the package if it is not yet installed
# devtools::install_github("jduijvenbode-WWF/ForestForesight")
library(ForestForesight)

# load data
data("countries")

# Gabon will be used as an example country
country="GAB" # use iso3 country code

##  Example with pre-trained model ##

# we will use the model provided by WWF which is trained on a group of countries
group = countries$group[countries$iso3==country]
modelname = paste0("D:/ff-dev/results/models/", group, "/", group, ".model")

# run train_predict_raster function
prediction_pretrained = ForestForesight::train_predict_raster(country=country,
                                      prediction_date = "2023-01-01",
                                      model = modelname,
                                      ff_folder = "D:/ff-dev/results", # folder containing the input data
                                      verbose = TRUE,
                                      label_threshold = 1,
                                      model_path = modelname,
                                      # when ground truth is available a accuracy csv can be created
                                      accuracy_csv = "D:/ff-dev/results/accuracy_analysis/example_Gabon_model.csv")

# plot the prediction probabilities
plot(prediction_pretrained)
# plot deforestation prediction (threshold of 0.5)
plot(prediction_pretrained>0.5)

## Example without pre-trained model ##

# Lets train a new model only on the data from Gabon

prediction_new_model = ForestForesight::train_predict_raster(country=country,
                                                              prediction_date = "2023-01-01",
                                                              train_start="2021-01-01", # the model will be trained on the year 2021
                                                              train_end="2021-12-01",
                                                              ff_folder = "D:/ff-dev/results", # folder containing the input data
                                                              verbose = TRUE,
                                                              label_threshold = 1,
                                                              model_path = "D:/ff-dev/results/GabonExampleModel.model", # where to save the model
                                                              # when ground truth is available a accuracy csv can be created
                                                              accuracy_csv = "D:/ff-dev/results/accuracy_analysis/example_Gabon_newmodel.csv")

# plot the prediction probabilities
plot(prediction_new_model)
# plot deforestation prediction (threshold of 0.5)
plot(prediction_new_model>0.5)



