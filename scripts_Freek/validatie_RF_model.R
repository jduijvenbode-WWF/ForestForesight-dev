# Load necessary libraries
library(randomForest)
library(openxlsx)

# Function to train RF model and return the model object and metrics
train_rf <- function(train_data, valid_data, valid_data_other_tile, ntrees, max_depth, seed = 123) {
  cat(sprintf("Using RF with ntrees=%d and max_depth=%d\n", ntrees, max_depth))
  
  set.seed(seed)
  
  # Extract features and labels from train and validation data
  train_features <- as.data.frame(train_data$data_matrix$features)
  train_label <- as.factor(train_data$data_matrix$label)
  valid_features <- as.data.frame(valid_data$validation_matrix$features)
  valid_label <- as.factor(valid_data$validation_matrix$label)
  
  # Combine features and labels into data frames
  train_df <- cbind(train_features, label = train_label)
  valid_df <- cbind(valid_features, label = valid_label)
  
  # Train RF model with specified parameters
  model <- randomForest(
    x = train_df[ , -ncol(train_df)],
    y = train_df$label,
    ntree = ntrees,
    mtry = floor(sqrt(ncol(train_df) - 1)),
    maxnodes = max_depth
  )
  
  # Validate the model using the validation data
  predicted_labels_valid <- predict(model, valid_df[ , -ncol(valid_df)])
  true_labels_valid <- valid_df$label
  
  conf_matrix_valid <- table(Actual = true_labels_valid, Predicted = predicted_labels_valid)
  
  # Manually calculate the confusion matrix for validation data
  TP_valid <- conf_matrix_valid[2, 2]  # True Positives
  TN_valid <- conf_matrix_valid[1, 1]  # True Negatives
  FP_valid <- conf_matrix_valid[1, 2]  # False Positives
  FN_valid <- conf_matrix_valid[2, 1]  # False Negatives
  
  # Calculate precision, recall, and F0.5 score for validation data
  precision_valid <- TP_valid / (TP_valid + FP_valid)
  recall_valid <- TP_valid / (TP_valid + FN_valid)
  f_beta_valid <- 1.25 * (precision_valid * recall_valid) / (0.25 * precision_valid + recall_valid)
  
  # Print metrics for validation data
  cat("\nMetrics for validation data:\n")
  cat("Precision:", precision_valid, "\n")
  cat("Recall:", recall_valid, "\n")
  cat("F0.5 Score:", f_beta_valid, "\n")
  
  # Print confusion matrix for validation data
  cat("\nConfusion Matrix for validation data:\n")
  print(conf_matrix_valid)
  
  # Predict on other validation tile if provided
  if (!missing(valid_data_other_tile)) {
    # Extract features and labels from other validation data
    other_tile_features <- as.data.frame(valid_data_other_tile$data_matrix$features)
    other_tile_label <- as.factor(valid_data_other_tile$data_matrix$label)
    
    # Predict with the trained model on other validation data
    predicted_labels_other_tile <- predict(model, other_tile_features)
    
    # Create confusion matrix for other validation data
    conf_matrix_other_tile <- table(Actual = other_tile_label, Predicted = predicted_labels_other_tile)
    
    # Manually calculate the confusion matrix for other validation data
    TP_other_tile <- conf_matrix_other_tile[2, 2]  # True Positives
    FP_other_tile <- conf_matrix_other_tile[1, 2]  # False Positives
    FN_other_tile <- conf_matrix_other_tile[2, 1]  # False Negatives
    
    # Calculate precision, recall, and F0.5 score for other validation data
    precision_other_tile <- TP_other_tile / (TP_other_tile + FP_other_tile)
    recall_other_tile <- TP_other_tile / (TP_other_tile + FN_other_tile)
    f_beta_other_tile <- 1.25 * (precision_other_tile * recall_other_tile) / (0.25 * precision_other_tile + recall_other_tile)
    
    # Print metrics for other validation data
    cat("\nMetrics for other validation data:\n")
    cat("Precision:", precision_other_tile, "\n")
    cat("Recall:", recall_other_tile, "\n")
    cat("F0.5 Score:", f_beta_other_tile, "\n")
    
    # Print confusion matrix for other validation data
    cat("\nConfusion Matrix for other validation data:\n")
    print(conf_matrix_other_tile)
    
    # Return metrics for other validation data
    return(list(
      validation_metrics = list(precision = precision_valid, recall = recall_valid, f_beta = f_beta_valid, confusion_matrix = conf_matrix_valid),
      other_tile_metrics = list(precision = precision_other_tile, recall = recall_other_tile, f_beta = f_beta_other_tile, confusion_matrix = conf_matrix_other_tile)
    ))
  } else {
    # Return metrics for only validation data
    return(list(
      validation_metrics = list(precision = precision_valid, recall = recall_valid, f_beta = f_beta_valid, confusion_matrix = conf_matrix_valid)
    ))
  }
}

# Train RF model with specific parameters and evaluate on other validation dataset if provided
results <- train_rf(train_data_300k, valid_data_300k, valid_data_other_tile, ntrees = 30, max_depth = 10)

# Print the results for validation data and other validation data if evaluated
if (length(results) == 1) {
  print("Validation Data Metrics:")
  print(results$validation_metrics)
} else {
  print("Validation Data Metrics:")
  print(results$validation_metrics)
  print("\nOther Validation Data Metrics:")
  print(results$other_tile_metrics)
}

