library(kknn)
library(openxlsx)
library(ggplot2)

# Function to perform KNN classification and compute metrics
train_knn_incremental <- function(train_data, validate_data, k = 3, kernel = "rectangular", threshold = 0.5) {
  
  # Extract features and labels from matrices
  train_features <- as.data.frame(train_data$data_matrix$features)
  validate_features <- as.data.frame(validate_data$validation_matrix$features)
  
  # Ensure labels are in the correct format (vector)
  train_labels <- as.factor(train_data$data_matrix$label)
  validate_labels <- as.factor(validate_data$validation_matrix$label)
  
  # Combine features and labels into one data frame
  train_df <- cbind(train_features, label = train_labels)
  validate_df <- cbind(validate_features, label = validate_labels)
  
  # Initialize lists to store metrics
  proportions <- seq(0.1, 1, by = 0.05)  # From 10% to 100% of the data
  f0_5_scores <- numeric()
  precision_scores <- numeric()
  recall_scores <- numeric()
  data_used <- numeric()
  
  for (prop in proportions) {
    cat("\nTraining with", prop * 100, "% of the data\n")
    
    # Subset the training data
    sample_size <- floor(prop * nrow(train_df))
    sample_indices <- sample(seq_len(nrow(train_df)), size = sample_size)
    train_subset <- train_df[sample_indices, ]
    
    # Train the KNN model
    knn_model <- kknn(label ~ ., train_subset, validate_df, k = k, kernel = kernel)
    
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
    
    # Store metrics
    f0_5_scores <- c(f0_5_scores, f_beta * 100)  # Scale F0.5 to percentage
    precision_scores <- c(precision_scores, precision * 100)
    recall_scores <- c(recall_scores, recall * 100)
    data_used <- c(data_used, sample_size)
    
    # Print metrics
    cat("F0.5 Score:", f_beta, "\n")
    cat("Precision:", precision, "\n")
    cat("Recall:", recall, "\n")
    cat("Confusion Matrix:\n")
    print(conf_matrix)
  }
  
  # Create data frame for results
  results_df <- data.frame(
    DataUsed = data_used,
    F0.5_Score = f0_5_scores,
    Precision = precision_scores,
    Recall = recall_scores
  )
  
  # Plot the learning curves
  learning_curve_plot <- ggplot(results_df, aes(x = DataUsed)) +
    geom_line(aes(y = F0.5_Score, color = "F0.5 Score")) +
    geom_line(aes(y = Precision, color = "Precision")) +
    geom_line(aes(y = Recall, color = "Recall")) +
    scale_color_manual(values = c("F0.5 Score" = "red", "Precision" = "blue", "Recall" = "green")) +
    labs(title = "Learning Curve for KNN Model",
         x = "Training Datasize",
         y = "Score (%)",
         color = "Metric") +
    theme_minimal() +
    scale_y_continuous(labels = scales::percent_format(scale = 1), limits = c(0, 100)) +
    scale_x_continuous(labels = scales::comma)
  
  return(learning_curve_plot)
}

# Example usage:
set.seed(123)
learning_curve_plot <- train_knn_incremental(train_data_300k, valid_data_300k, k = 3, kernel = "rectangular")
print(learning_curve_plot)
