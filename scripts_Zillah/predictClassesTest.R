

# Set the quantile values
catQuantiles = c(0.5, 0.90)

# load a train data set
trainDataTest = ff_prep(datafolder = "D:/ff-dev/results/preprocessed/",
                  country = "COL",start = "2022-01-01", end="2022-12-01",
                  fltr_features = "initialforestcover",fltr_condition = ">0",
                  verbose = F,shrink = "extract",addxy = F,
                  groundtruth_pattern = "groundtruth6m", sample_size = 0.1)


# Only select pixels where deforestation is predicted
defInd = trainDataTest$data_matrix$label>0
trainDataTest$data_matrix$label= trainDataTest$data_matrix$label[defInd]
trainDataTest$data_matrix$features = trainDataTest$data_matrix$features[defInd,]

# Transform labels
trainLabels=trainDataTest$data_matrix$label
mooimm

# Note XGBoost requires that the class labels start at 0 and increase sequentially to the maximum number of classes
categorized <- cut(trainLabels, breaks = c(0,unname(catLabels),1600), labels=seq(0,length(catQuantiles)), right = FALSE, include.lowest = TRUE)

trainDataTest$data_matrix$label= as.numeric(categorized)-1


#  "num_class" = numberOfClasses
model = ff_train(trainDataTest$data_matrix,eta = 0.2,gamma = 0.2,min_child_weight = 3,max_depth = 6,
                 nrounds = 100,subsample = 0.3,verbose = T, features = alldata$features,
                 eval_metric = "mlogloss", objective = "multi:softprob", num_class = length(catQuantiles)+1)
tile= "10N_080W"
date= "2023-01-01"
predset = ff_prep(datafolder = "D:/ff-dev/results/preprocessed/",tiles = tile,
                  start = date,verbose = F,fltr_features = "initialforestcover",
                  fltr_condition = ">0",addxy = F,
                  groundtruth_pattern = "groundtruth6m")

defPred =  rast(paste0("D:/ff-dev/results/predictions/", tile,"/", tile, "_", date,"_predictions.tif"))>50

predset$data_matrix$label=predset$data_matrix$label[defPred[predset$testindices][,1]]
predset$data_matrix$features=predset$data_matrix$features[defPred[predset$testindices][,1],]
testLabels=predset$data_matrix$label

categorizedTest <- cut(testLabels, breaks = c(0,unname(catLabels),1600), labels=seq(0,length(catQuantiles)), right = FALSE, include.lowest = TRUE)
predset$data_matrix$label= as.numeric(categorizedTest)-1
prediction = predict(model, xgboost::xgb.DMatrix(predset$data_matrix$features))
pred_mat= matrix(prediction, ncol=3, byrow = T)

best_prediction = max.col(pred_mat)-1


library("caret")
CM=confusionMatrix(factor(best_prediction, levels=c("0","1","2")),
                categorizedTest,
                mode = "everything")

templateRast= predset$groundtruthraster
templateRast[predset$testindices]= best_prediction
plot(templateRast)
