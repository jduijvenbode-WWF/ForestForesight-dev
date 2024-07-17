library(h2o)

# Initialize H2O
h2o.init()

get_models_from_leaderboard <- function(leaderboard) {
  # Extract model IDs from the leaderboard
  model_ids <- as.vector(leaderboard$model_id)
  
  # Create an empty list to store model objects
  models <- list()
  
  # Loop through the model IDs and get each model
  for (i in seq_along(model_ids)) {
    models[[paste0("model", i)]] <- h2o.getModel(model_ids[i])
  }
  
  return(models)
}

# model_dict <- get_models_from_leaderboard(lb)
# model_1 <- model_dict[["model1"]]
# history <- model_1@model$scoring_history


# Define the function to get models from the leaderboard
get_models_from_leaderboard <- function(leaderboard) {
  # Extract model IDs and names from the leaderboard
  model_ids <- as.vector(leaderboard$model_id)
  model_names <- as.vector(leaderboard$model_id)  # Assuming model_id is the name
  
  # Create a data frame to store model IDs and names
  models <- data.frame(model_id = model_ids, model_name = model_names)
  
  return(models)
}

# Define a function to get model parameters
get_model_parameters <- function(model) {
  params <- h2o.getModelParameters(model)
  return(params)
}

# Define the function to calculate F0.5, precision, and recall on validation data
calculate_validation_metrics <- function(model, model_name, validation_data) {
  # Calculate performance metrics
  performance <- h2o.performance(model, newdata = validation_data)
  
  # Get the threshold that maximizes the F0.5 score
  threshold <- h2o.find_threshold_by_max_metric(performance, "f0point5")
  
  # Get precision and recall at this threshold
  precision <- h2o.precision(performance, thresholds = threshold)
  recall <- h2o.recall(performance, thresholds = threshold)
  
  # Get F0.5 score at this threshold
  f0.5 <- h2o.F0point5(performance, thresholds = threshold)
  
  # Return the metrics, model name, and parameters
  return(list(
    model_name = model_name,
    precision = precision,
    recall = recall,
    f0.5 = f0.5,
    parameters = get_model_parameters(model)
  ))
}

get_valid_data_h20 <- function(valid_data){
  
  x_validation <- valid_data$validation_matrix$features
  y_validation <- factor(valid_data$validation_matrix$label, levels = c(0, 1))
  levels(y_validation) <- c("not_deforested", "deforested")
  
  valid_data <- cbind(x_validation, label = y_validation)
  
  valid_h2o <- as.h2o(valid_data)
  
  valid_h2o$label <- as.factor(valid_h2o$label)
  
  return(valid_h2o)
}