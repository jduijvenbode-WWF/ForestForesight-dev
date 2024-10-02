library(ForestForesight)
library(xgboost)

traindata_all <- ff_prep(datafolder = "D:/ff-dev/results/preprocessed",
                         country = "BOL" ,
                         start = "2022-01-01",
                         end = "2022-12-01" ,
                         fltr_condition = ">0",
                         fltr_features = "initialforestcover",
                         sample_size = 0.2,
                         shrink = "extract",
                         label_threshold = 1)

# Train A model on 2022 excluding new features
exc_features = c("firealerts", "losslastyear", "nightlights", "totaldeforestation", "peatland", 
                  "populationincrease", "sinmonth", "slope", "totallossalerts", "wetlands", 
                  "x", "y", "monthssince2019", "landpercentage", "catexcap", "wdpa", 
                  "croplandcapacity100p", "croplandcapacitybelow50p", "croplandcapacityover50p", 
                  "closenesstocropland", "cattlesmoothed", "closenesstocattleabove2000", 
                  "closenesstocattleabove10000", "palmoilmills", "soybeansmoothed", 
                  "closenesstocoffee", "closenesstofiber", "closenesstorice", "dpicoal", 
                  "dpihydro", "dpimetalicmining", "dpinonmetalicmining", "miningsmoothed", 
                  "diminishinghotspot", "sporadichotspot", "intensifyinghotspot", 
                  "newhotspot", "persistenthotspot")
traindata_exc_features = list()
traindata_exc_features$data_matrix$features = traindata_all$data_matrix$features[,!colnames(traindata_all$data_matrix$features) %in% exc_features]
traindata_exc_features$data_matrix$label = traindata_all$data_matrix$label
traindata_exc_features$features = colnames(traindata_exc_features$data_matrix$features)

group <- "BOL"

# Train the model excluding the specified features
model_exc <- ff_train(traindata_exc_features$data_matrix,
                      modelfilename = paste0("D:/temp/ResultsStijn/models2022/30mostimportant/", group, "_30mostimportant2.model"), # Save the model with an appropriate name
                      features = traindata_exc_features$features)
