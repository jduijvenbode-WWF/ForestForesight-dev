# mlflow::mlflow_set_tracking_uri("http://ec2-3-255-204-156.eu-west-1.compute.amazonaws.com:5000/")
# # Get experiment by name
# experiment <- mlflow::mlflow_get_experiment(name = experiment_name)
# if (is.null(experiment)) {
#   stop("Experiment not found: ", experiment_name)
# }
# # Get all runs for this experiment
# runs <- mlflow::mlflow_search_runs(
#   experiment_ids = experiment$experiment_id,
#   order_by = "start_time DESC"
# )
# F0.5 = sapply(runs$metrics, function(x) data.frame(x))
# # Extract F0.5 scores if they exist
# f0.5_scores <- data.frame(
#   run_id = runs$run_id,
#   status = runs$status,
#   F0.5 = sapply(runs$metrics,function(x) get_score(x)), # Assuming the metric is stored as 'f0.5'
#   start_time = runs$start_time
# )
# return(f0.5_scores)
# }
# scores <- get_f0.5_scores("Bolivia")
# for(group in groups){
#   scores <- get_f0.5_scores(group)
#   mlflow::mlflow_set_tag(key = "algorithm",value="baseline",run_id = scores$run_id)
# }
# group
# for(group in groups){
#   scores <- get_f0.5_scores(group)
#   mlflow::mlflow_set_tag(key = "algorithm",value="baseline",run_id = scores$run_id)
# }


setwd("C:/data/storage/experimentation/mlflow/")
library(ForestForesight)
groups=list.dirs(path = "accuracy_20241202/",full.names = T,recursive = T)
#get(data(countries))$group[which(!get(data(countries))$group %in% basename(groups))]
groups=groups[-1]
for(group in groups[1:length(groups)]){
  accuracy=read.csv(list.files(path=group,pattern="small",full.names = T))
  model=load_model(list.files(path=gsub("accuracy","models",group),pattern="2_small.model",full.names = T))
  aucpr=model$best_score
  calculate_metrics <- function(df) {
    sums <- colSums(df[, c("FP", "FN", "TP", "TN")])
    precision <- sums["TP"] / (sums["TP"] + sums["FP"])
    recall <- sums["TP"] / (sums["TP"] + sums["FN"])
    f_score <- (1 + 0.5^2) * (precision * recall) / ((0.5^2 * precision) + recall)
    return(list(
      "Precision"=as.numeric(precision), "Recall"= as.numeric(recall), "F0.5"=as.numeric(f_score)))
  }
  metrics <- calculate_metrics(accuracy)
  # Use it like:

  parameters <- list(
    eta = 0.1,
    subsample = 0.75,
    max_depth = 5,
    data_sample_fraction = "auto",
    validation_sample_fraction = 0.25,
    start_date_training = "2022-01-01",
    end_date_training = "2022-12-01",
    validation_date_start = "2022-01-01",
    validation_date_end = "2022-12-01",
    nrounds = 200,
    eval_metric = "aucpr",
    stopping_rounds = 10,
    minimum_child_weight = 1,
    objective = "maximize",
    feature_list = paste0(model$feature_names,collapse=", ")
  )

  # Metrics list
  metrics <- list(
    precision = metrics$Precision,
    recall = metrics$Recall,
    F0.5 = as.numeric(metrics$F0.5),
    TP = sum(accuracy$TP,na.rm=T),
    FP = sum(accuracy$FP,na.rm=T),
    FN = sum(accuracy$FN,na.rm=T),
    TN = sum(accuracy$TN,na.rm=T),
    AUC = model$best_score
  )
  ff_log_model(region_name = basename(group),method_iteration = "xgboost - small model",model=model,params_list = parameters,metrics_list = metrics)
}
