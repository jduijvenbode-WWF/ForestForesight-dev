library(e1071)
library(openxlsx)
library(ggplot2)
library(scales)

# Function to perform Naive Bayes classification, compute F0.5 score, and plot learning curve
naive_bayes_learningcurve <- function(train_data, validate_data, threshold = 0.5) {

  # Extract features and labels from training and validation data
  train_features <- train_data$data_matrix$features
  train_labels <- train_data$data_matrix$label
  validate_features <- validate_data$validation_matrix$features
  validate_labels <- validate_data$validation_matrix$label

  # Initialize lists to store F0.5 scores and means
  f0_5_scores <- numeric()
  means_list <- list()

  # Define the proportion of training data to use in each iteration
  proportions <- seq(0.1, 1, by = 0.1)  # From 10% to 100% of the data

  # Loop through proportions of training data
  for (prop in proportions) {
    cat("\nNaive Bayes Model with Training Data Proportion:\n")
    cat("Proportion =", prop, "\n")

    # Subset the training data
    sample_size <- floor(prop * nrow(train_features))
    sample_indices <- sample(seq_len(nrow(train_features)), size = sample_size)

    train_features_subset <- train_features[sample_indices, ]
    train_labels_subset <- train_labels[sample_indices]

    # Check if subset is empty (shouldn't happen with current loop setup)
    if (nrow(train_features_subset) == 0) {
      cat("Skipping empty training subset for proportion", prop, "\n")
      next
    }

    # Train the Naive Bayes model
    nb_model <- naiveBayes(train_features_subset, train_labels_subset)

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

    # Calculate F0.5 score
    precision <- ifelse((TP + FP) == 0, 0, TP / (TP + FP))
    recall <- ifelse((TP + FN) == 0, 0, TP / (TP + FN))
    f_beta <- ifelse((0.25 * precision + recall) == 0, 0, 1.25 * (precision * recall) / (0.25 * precision + recall))

    # Store F0.5 score
    f0_5_scores <- c(f0_5_scores, f_beta)

    # Extract means (feature importance proxy)
    means <- sapply(nb_model$tables, function(x) {
      if ("mean" %in% colnames(x)) {
        x[, "mean"] * 100  # Scale to percentage if "mean" column exists
      } else {
        rep(NA, ncol(x))  # Return NA if "mean" column doesn't exist
      }
    })

    # Flatten means list to remove nested structures
    means <- unlist(means)
    means_list[[paste("proportion", prop, sep = "_")]] <- means

    # Print the F0.5 score for the current model
    cat("F0.5 Score:", f_beta, "\n")

    # Print confusion matrix
    cat("\nConfusion Matrix:\n")
    print(conf_matrix)
  }

  # Convert F0.5 scores to a data frame for easier manipulation
  results <- data.frame(
    Model = rep("Naive Bayes", length(proportions)),
    Proportion = proportions,
    F0.5 = f0_5_scores * 100  # Scale to percentage
  )

  # Plot learning curve: F0.5 score against the amount of data used
  learning_curve_plot <- ggplot(results, aes(x = Proportion, y = F0.5)) +
    geom_line() +
    geom_point() +
    labs(title = "Learning Curve Naive Bayes Model",
         x = "Proportion of Training Data Used",
         y = "F0.5 Score (%)") +
    theme_minimal() +
    scale_y_continuous(labels = percent_format(scale = 1), limits = c(0, 100))

  # Identify the model with the highest F0.5 score
  best_prop <- proportions[which.max(f0_5_scores)]
  best_means <- means_list[[paste("proportion", best_prop, sep = "_")]]

  # Check if best_means is empty or contains only NAs
  if (length(best_means) == 0 || all(is.na(best_means))) {
    cat("Warning: No valid means available for the best model.\n")
    means_plot <- NULL
  } else {
    # Convert means to a data frame for plotting and scale to percentage
    means_df <- data.frame(Feature = names(best_means), Mean = best_means)

    # Plot means for each feature
    means_plot <- ggplot(means_df, aes(x = Feature, y = Mean)) +
      geom_bar(stat = "identity") +
      labs(title = "Feature Importance (Means) for Best Model",
           x = "Feature",
           y = "Mean (%)") +
      theme_minimal() +
      theme(axis.text.x = element_text(angle = 90, hjust = 1)) +
      scale_y_continuous(labels = percent_format(scale = 1))
  }

  # Return the learning curve plot and feature importance plot
  return(list(learning_curve_plot = learning_curve_plot, means_plot = means_plot))
}

# Example usage:
# Assuming train_data and validate_data are already defined

# naive_bayes_learningcurve(train_data, validate_data, threshold = 0.5)
