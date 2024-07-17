library(kknn)
library(openxlsx)

# Function to perform KNN classification and compute metrics
train_knn_params <- function(train_data, validate_data, k = 3, threshold = 0.5, kernel = "rectangular") {

  # Extract features and labels from matrices
  train_features <- as.data.frame(train_data$data_matrix$features)
  validate_features <- as.data.frame(validate_data$validation_matrix$features)

  # Ensure labels are in the correct format (vector)
  train_labels <- as.factor(train_data$data_matrix$label)
  validate_labels <- as.factor(validate_data$validation_matrix$label)

  # Combine features and labels into one data frame
  train_df <- cbind(train_features, label = train_labels)
  validate_df <- cbind(validate_features, label = validate_labels)

  # Train the KNN model
  knn_model <- kknn(label ~ ., train_df, validate_df, k = k, kernel = kernel)

  # Predict probabilities and convert to binary predictions based on threshold
  knn_pred_probs <- fitted(knn_model)
  knn_pred <- ifelse(knn_pred_probs > threshold, 1, 0)

  # Create confusion matrix
  conf_matrix <- table(Actual = validate_labels, Predicted = knn_pred)

  # Extract TP, TN, FP, FN
  TP <- conf_matrix[2, 2]  # True Positives
  TN <- conf_matrix[1, 1]  # True Negatives
  FP <- conf_matrix[1, 2]  # False Positives
  FN <- conf_matrix[2, 1]  # False Negatives

  # Calculate precision, recall, and F0.5 score
  precision <- TP / (TP + FP)
  recall <- TP / (TP + FN)
  f_beta <- 1.25 * (precision * recall) / (0.25 * precision + recall)

  # Print precision, recall, and F0.5 score
  cat("k =", k, "\n")
  cat("Kernel:", kernel, "\n")
  cat("Precision:", precision, "\n")
  cat("Recall:", recall, "\n")
  cat("F0.5 Score:", f_beta, "\n")

  # Print confusion matrix
  cat("\nConfusion Matrix:\n")
  print(conf_matrix)

  # Return metrics
  return(list(model = knn_model, precision = precision, recall = recall, f_beta = f_beta, confusion_matrix = conf_matrix))
}

# Initialize list to store models and their metrics
models_list <- list()

# Iterate over the range of neighbors (3 to 9) and different kernels
kernels <- c("rectangular", "triangular", "epanechnikov", "biweight", "triweight", "cos", "inv", "gaussian", "optimal", "rank")
for (kernel in kernels) {
  for (k in seq(3, 9, by = 2)) {
    cat("\nModel with k =", k, "and kernel =", kernel, "\n")
    result <- train_knn_params(train_data_100k, valid_data_100k, k = k, kernel = kernel)
    model_name <- paste("k", k, "kernel", kernel, sep = "_")
    models_list[[model_name]] <- result
  }
}

# Convert results to a data frame for easier manipulation
results <- data.frame(
  Model = rep("KNN", length(models_list)),
  Parameters = names(models_list),
  F0.5 = sapply(models_list, function(x) x$f_beta),
  Precision = sapply(models_list, function(x) x$precision),
  Recall = sapply(models_list, function(x) x$recall)
)

# Write results to an Excel sheet with dynamic naming
file_name <- paste("model_results_KNN.xlsx", sep = "")
write.xlsx(results, file_name)
