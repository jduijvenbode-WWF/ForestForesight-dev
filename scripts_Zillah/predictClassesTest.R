

# Set the quantile values
catQuantiles = c(0.5,0.75, 0.90)

# laod a train data set
trainDataTest = ff_prep(datafolder = "D:/ff-dev/results/preprocessed/",
                  country = "LAO",start = "2022-01-01",
                  fltr_features = "initialforestcover",fltr_condition = ">0",
                  verbose = F,shrink = "extract",addxy = F,
                  groundtruth_pattern = "groundtruth6m")
# Transform labels
trainLabels=trainDataTest$data_matrix$label
catLabels = quantile(trainLabels[trainLabels>0], probs=catQuantiles)

# Note XGBoost requires that the class labels start at 0 and increase sequentially to the maximum number of classes
categorized <- cut(trainLabels, breaks = c(0,1,unname(catLabels),1600), labels=seq(0,length(catQuantiles)+1), right = FALSE, include.lowest = TRUE)

trainDataTest$data_matrix$label= as.numeric(categorized)-1


#  "num_class" = numberOfClasses
model = ff_train(trainDataTest$data_matrix,eta = 0.2,gamma = 0.2,min_child_weight = 3,max_depth = 6,
                 nrounds = 100,subsample = 0.3,verbose = T, features = alldata$features,
                 eval_metric = "mlogloss", objective = "multi:softprob", num_class = length(catQuantiles)+2)

predset = ff_prep(datafolder = "D:/ff-dev/results/preprocessed/",tiles = "20N_100E",
                  start = "2023-01-01",verbose = F,fltr_features = "initialforestcover",
                  fltr_condition = ">0",addxy = F,
                  groundtruth_pattern = "groundtruth6m")
testLabels=predset$data_matrix$label
categorizedTest <- cut(testLabels, breaks = c(0,1,unname(catLabels),1600), labels=seq(0,length(catQuantiles)+1), right = FALSE, include.lowest = TRUE)
predset$data_matrix$label= as.numeric(categorizedTest)-1
prediction = predict(model, xgboost::xgb.DMatrix(predset$data_matrix$features))
pred_mat= matrix(prediction, ncol=5, byrow = T)

best_prediction = max.col(pred_mat)-1



library("caret")
CM=confusionMatrix(factor(best_prediction, levels=c("0","1","2","3","4")),
                categorizedTest,
                mode = "everything")

templateRast= predset$groundtruthraster
templateRast[predset$testindices]= best_prediction
plot(templateRast)
