
# This scripts provides an example on how to:
# 1) Load a model
# 2) Get the feature importance
# 3) plot feature importance
# 4) save the feature importance to a csv file
#

# 1) Load the model (adjust file path to the model of interest)
modelname = "D:/ff-dev/results/models/Eastern Africa 2/Eastern Africa 2.model"
model = xgboost::xgb.load(modelname)
model_features <- get(load(gsub("\\.model","\\.rda",modelname)))
attr(model,"feature_names") <- model_features
model

# 2) Get the feature importance
importance_matrix <- xgb.importance(model = model)
print(importance_matrix)
importance_matrix$fnum = as.numeric(gsub("f","",importance_matrix$Feature)) + 1
importance_matrix$Feature = model_features[importance_matrix$fnum]

# 3) plot the feature importance
xgb.plot.importance(importance_matrix = importance_matrix)

# 4) save the feature importance to a csv file
write.csv(importance_matrix[,1:2],"D:/ff-dev/results/feature_importance/test.csv")

