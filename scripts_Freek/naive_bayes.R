library(e1071)
library(openxlsx)

# Function to perform Naive Bayes classification and compute metrics
naive_bayes_metrics <- function(train_data, validate_data, threshold = 0.5) {
  
  # Extract features and labels from matrices
  train_features <- train_data$data_matrix$features
  validate_features <- validate_data$validation_matrix$features
  
  # Ensure labels are in the correct format (vector)
  train_labels <- train_data$data_matrix$label
  validate_labels <- validate_data$validation_matrix$label
  
  # Train the Naive Bayes model
  nb_model <- naiveBayes(train_features, train_labels)
  
  # Predict probabilities and convert to binary predictions based on threshold
  nb_pred_probs <- predict(nb_model, validate_features, type = "raw")[, 2]
  nb_pred <- ifelse(nb_pred_probs > threshold, 1, 0)
  
  # Create confusion matrix
  conf_matrix <- table(Actual = validate_labels, Predicted = nb_pred)
  
  # Extract TP, TN, FP, FN
  TP <- conf_matrix[2, 2]  # True Positives
  TN <- conf_matrix[1, 1]  # True Negatives
  FP <- conf_matrix[1, 2]  # False Positives
  FN <- conf_matrix[2, 1]  # False Negatives
  
  # Calculate precision, recall, and F0.5 score
  precision <- TP / (TP + FP)
  recall <- TP / (TP + FN)
  f_beta <- 1.25 * (precision * recall) / (0.25 * precision + recall)
  
  # Return metrics
  return(list(model = nb_model, precision = precision, recall = recall, f_beta = f_beta, confusion_matrix = conf_matrix))
}

# Initialize list to store models and their metrics
models_list <- list()

# Define different threshold values to search
thresholds <- c(0.2, 0.3, 0.4, 0.5, 0.6, 0.7)

# Loop through threshold values
for (threshold in thresholds) {
  cat("\nNaive Bayes Model with Parameters:\n")
  cat("Threshold =", threshold, "\n")
  
  # Run Naive Bayes and store the result
  result <- naive_bayes_metrics(train_data, valid_data, threshold = threshold)
  
  # Store the result in models_list with a key that identifies the threshold
  param_key <- paste("threshold", threshold, sep = "_")
  models_list[[param_key]] <- result
  
  # Print metrics for the current model
  cat("Precision:", result$precision, "\n")
  cat("Recall:", result$recall, "\n")
  cat("F0.5 Score:", result$f_beta, "\n")
  
  # Print confusion matrix
  cat("\nConfusion Matrix:\n")
  print(result$confusion_matrix)
}

# Convert results to a data frame for easier manipulation
results <- data.frame(
  Model = rep("Naive Bayes", length(models_list)),
  Parameters = names(models_list),
  F0.5 = sapply(models_list, function(x) x$f_beta),
  Precision = sapply(models_list, function(x) x$precision),
  Recall = sapply(models_list, function(x) x$recall)
)

# Write results to an Excel sheet with dynamic naming
file_name <- "model_results/naive_bayes_results.xlsx"
write.xlsx(results, file_name)
