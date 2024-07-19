# Load necessary libraries
library(e1071)
library(caret)
library(ggplot2)

# Function to perform SVM classification and compute metrics
train_svm_incremental <- function(train_data, validate_data, kernel = "linear", cost = 1, gamma = 0.1, max_iter = 1000, threshold = 0.5) {
  
  # Extract features and labels from matrices
  train_features <- as.data.frame(train_data$data_matrix$features)
  validate_features <- as.data.frame(validate_data$validation_matrix$features)
  
  # Ensure labels are in the correct format (vector)
  train_labels <- as.factor(train_data$data_matrix$label)
  validate_labels <- as.factor(validate_data$validation_matrix$label)
  
  # Standardize the features using training data parameters
  preProc <- preProcess(train_features, method = c("center", "scale"))
  train_features <- predict(preProc, train_features)
  validate_features <- predict(preProc, validate_features)
  
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
    
    # Train the SVM model
    svm_model <- svm(label ~ ., data = train_subset, kernel = kernel, cost = cost, gamma = gamma, probability = TRUE, max_iter = max_iter)
    
    # Predict probabilities
    svm_pred_probs <- predict(svm_model, validate_df[, -ncol(validate_df)], probability = TRUE)
    attr_probs <- attr(svm_pred_probs, "probabilities")
    
    # Extract the probabilities for the positive class
    svm_pred_probs <- attr_probs[, 2]
    
    # Round predicted probabilities to integers (0 or 1)
    svm_pred <- as.factor(ifelse(svm_pred_probs >= threshold, 1, 0))
    
    # Create confusion matrix
    conf_matrix <- table(Actual = validate_labels, Predicted = svm_pred)
    
    # Simplified extraction of TP, TN, FP, FN
    TP <- conf_matrix[2, 2]
    TN <- conf_matrix[1, 1]
    FP <- conf_matrix[1, 2]
    FN <- conf_matrix[2, 1]
    
    # Calculate precision, recall, and F0.5 score
    precision <- ifelse((TP + FP) > 0, TP / (TP + FP), 0)
    recall <- ifelse((TP + FN) > 0, TP / (TP + FN), 0)
    f_beta <- ifelse((0.25 * precision + recall) > 0, 1.25 * (precision * recall) / (0.25 * precision + recall), 0)
    
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
    geom_line(aes(y = F0.5_Score, color = "F0.5 Score"), size = 1.2) +
    geom_line(aes(y = Precision, color = "Precision"), size = 1.2) +
    geom_line(aes(y = Recall, color = "Recall"), size = 1.2) +
    scale_color_manual(values = c("F0.5 Score" = "red", "Precision" = "blue", "Recall" = "green")) +
    labs(title = "Learning Curve for SVM Model",
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
learning_curve_plot <- train_svm_incremental(train_data, valid_data, kernel = "linear", cost = 1, gamma = 0.1, max_iter = 1000)
print(learning_curve_plot)
