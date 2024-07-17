library(e1071)
library(openxlsx)
library(caret) # For preProcess function

# Function to perform SVM classification and compute metrics
train_svm_params <- function(train_data, validate_data, kernel = "linear", cost = 1) {
  
  # Extract features and labels from matrices
  train_features <- as.data.frame(train_data$data_matrix$features)
  validate_features <- as.data.frame(validate_data$validation_matrix$features)
  
  # Scale features
  preProc <- preProcess(train_features, method = c("center", "scale"))
  train_features <- predict(preProc, train_features)
  validate_features <- predict(preProc, validate_features)
  
  # Ensure labels are in the correct format (factor)
  train_labels <- as.factor(train_data$data_matrix$label)
  validate_labels <- as.factor(validate_data$validation_matrix$label)
  
  # Train the SVM model
  svm_model <- svm(x = train_features, y = train_labels, kernel = kernel, cost = cost)
  
  # Predict class labels
  svm_pred <- predict(svm_model, validate_features)
  
  # Create confusion matrix
  conf_matrix <- table(Actual = validate_labels, Predicted = svm_pred)
  
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
  cat("Kernel:", kernel, "\n")
  cat("Cost:", cost, "\n")
  cat("Precision:", precision, "\n")
  cat("Recall:", recall, "\n")
  cat("F0.5 Score:", f_beta, "\n")
  
  # Print confusion matrix
  cat("\nConfusion Matrix:\n")
  print(conf_matrix)
  
  # Return metrics
  return(list(model = svm_model, precision = precision, recall = recall, f_beta = f_beta, confusion_matrix = conf_matrix, preProc = preProc))
}

# Function to find the best model based on F0.5 score
find_best_model <- function(results) {
  best_index <- which.max(results$F0.5)
  best_model_name <- results$Model[best_index]
  best_model <- models_list[[best_model_name]]
  return(best_model)
}

# Initialize list to store models and their metrics
models_list <- list()

# Define the parameters to iterate over
kernels <- c("linear", "radial", "sigmoid", "polynomial")
cost_values <- c(0.1, 1, 10)

# Iterate over the different kernels and cost values
for (kernel in kernels) {
  for (cost in cost_values) {
    cat("\nModel with kernel =", kernel, "cost =", cost, "\n")
    result <- train_svm_params(train_data_50k, valid_data_50k, kernel = kernel, cost = cost)
    model_name <- paste("svm_kernel", kernel, "cost", cost, sep = "_")
    models_list[[model_name]] <- result
    saveRDS(list(model = result$model, preproc = result$preproc), file = paste("/models/knn", model_name))
  }
}

# Convert results to a data frame for easier manipulation
results <- data.frame(
  Model = rep("SVM", length(models_list)),
  Parameters = names(models_list),
  F0.5 = sapply(models_list, function(x) x$f_beta),
  Precision = sapply(models_list, function(x) x$precision),
  Recall = sapply(models_list, function(x) x$recall)
)

# Find the best model based on F0.5 score
best_model <- find_best_model(results)

# Print confusion matrix for the best model
cat("\nBest Model Confusion Matrix:\n")
print(best_model$confusion_matrix)

# Write results to Excel
file_name <- "model_results_SVM.xlsx"
write.xlsx(results, file_name)

# Print confirmation
cat("Results exported to", file_name, "\n")
