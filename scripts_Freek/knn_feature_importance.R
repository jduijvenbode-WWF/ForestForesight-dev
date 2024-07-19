library(kknn)
library(openxlsx)
library(ggplot2)

# Function to perform KNN classification and compute metrics
train_knn_params <- function(train_data, validate_data, k = 5, threshold = 0.5, kernel = "rectangular") {
  
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
  
  # Predict probabilities
  knn_pred_probs <- fitted(knn_model)
  
  # Check if knn_pred_probs are factors and convert to numeric if necessary
  if (is.factor(knn_pred_probs)) {
    knn_pred_probs <- as.numeric(as.character(knn_pred_probs))
  }
  
  # Round predicted probabilities to integers (0 or 1)
  knn_pred <- round(knn_pred_probs)
  
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
  return(list(model = knn_model, precision = precision, recall = recall, f_beta = f_beta, confusion_matrix = conf_matrix, validate_df = validate_df, knn_pred = knn_pred))
}

# Set the parameters
k <- 5
kernel <- "rectangular"

# Train the KNN model with the specified parameters
cat("\nModel with k =", k, "and kernel =", kernel, "\n")
result <- train_knn_params(train_data_300k, valid_data_300k, k = k, kernel = kernel)

# Function to compute permutation importance
compute_permutation_importance <- function(model, validate_df, knn_pred, k = 5, kernel = "rectangular") {
  original_accuracy <- mean(knn_pred == validate_df$label)
  importances <- numeric(ncol(validate_df) - 1)
  names(importances) <- names(validate_df)[1:(ncol(validate_df) - 1)]
  
  for (feature in names(importances)) {
    permuted_df <- validate_df
    permuted_df[[feature]] <- sample(permuted_df[[feature]])
    
    permuted_model <- kknn(label ~ ., permuted_df, permuted_df, k = k, kernel = kernel)
    permuted_pred_probs <- fitted(permuted_model)
    
    if (is.factor(permuted_pred_probs)) {
      permuted_pred_probs <- as.numeric(as.character(permuted_pred_probs))
    }
    
    permuted_pred <- round(permuted_pred_probs)
    permuted_accuracy <- mean(permuted_pred == validate_df$label)
    importances[feature] <- original_accuracy - permuted_accuracy
  }
  
  return(importances)
}

# Compute permutation importance
importances <- compute_permutation_importance(result$model, result$validate_df, result$knn_pred, k = k, kernel = kernel)

# Convert to percentages
importance_percent <- (importances / sum(importances)) * 100

# Convert to data frame for plotting
importance_df <- data.frame(Feature = names(importance_percent), Importance = importance_percent)

# Plot feature importance
p <- ggplot(importance_df, aes(x = reorder(Feature, Importance), y = Importance)) +
  geom_bar(stat = "identity") +
  coord_flip() +
  labs(title = "Feature Importance for KNN Model", x = "Feature", y = "Importance (%)") +
  theme_minimal()

# Print importance values
print(p)

# Print the importance data frame
print(importance_df)
