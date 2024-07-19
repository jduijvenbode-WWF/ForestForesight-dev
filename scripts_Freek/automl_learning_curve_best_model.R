library(ggplot2)
library(h2o)

# Function to train the model and plot learning curves
train_model_with_learning_curves <- function(train_data, valid_data, max_cores = 8) {
  # Initialize H2O
  if (is.null(max_cores)) {
    max_cores <- parallel::detectCores(logical = TRUE)  # Detect the number of available CPU cores
  }
  h2o.init(nthreads = max_cores)  # Initialize H2O with the specified number of threads
  cat(sprintf("Using %d CPU cores for parallel processing\n", max_cores))
  
  # Extract features and labels from the training and validation data
  x_train <- train_data$data_matrix$features
  y_train <- factor(train_data$data_matrix$label, levels = c(0, 1))
  x_validation <- valid_data$validation_matrix$features
  y_validation <- factor(valid_data$validation_matrix$label, levels = c(0, 1))
  
  # Combine features and labels
  train_data_combined <- cbind(x_train, label = y_train)
  valid_data_combined <- cbind(x_validation, label = y_validation)
  
  # Convert to H2O frames
  train_h2o <- as.h2o(train_data_combined)
  valid_h2o <- as.h2o(valid_data_combined)
  
  # Ensure labels are treated as factors
  train_h2o$label <- as.factor(train_h2o$label)
  valid_h2o$label <- as.factor(valid_h2o$label)
  
  cat("Training model...\n")
  
  # Train models using H2O AutoML
  automl_models <- h2o.automl(
    x = names(train_h2o)[-which(names(train_h2o) == "label")],
    y = "label",
    training_frame = train_h2o,
    validation_frame = valid_h2o,
    max_models = 15,
    max_runtime_secs = 3600,
    seed = 123
  )
  
  cat("Model trained\n")
  
  # Get the leaderboard and the best model
  leaderboard <- h2o.get_leaderboard(automl_models, extra_columns = "ALL")
  best_model <- h2o.getModel(leaderboard[1, "model_id"])
  print(best_model)
  
  # Define training sizes
  training_sizes <- seq(100, nrow(train_h2o), length.out = 50)
  training_sizes <- round(training_sizes)  # Ensure integer values
  
  # Initialize lists to store metrics
  valid_precision_values <- c()
  valid_recall_values <- c()
  valid_f0.5_values <- c()
  
  # Iterate over different training sizes
  for (size in training_sizes) {
    train_sample <- train_h2o[1:size, ]
    
    # Retrain the best model on the training sample
    model <- h2o.deeplearning(
      x = names(train_sample)[-which(names(train_sample) == "label")],
      y = "label",
      training_frame = train_sample,
      model_id = best_model@model_id,
      seed = 123
    )
    
    # Function to calculate metrics
    calculate_metrics <- function(predictions, actual_labels) {
      conf_matrix <- table(Actual = actual_labels, Predicted = predictions)
      
      # Check if true positives (TP) exist in the confusion matrix
      if (dim(conf_matrix)[1] < 2 || dim(conf_matrix)[2] < 2) {
        precision <- 0
        recall <- 0
        f_score <- 0
      } else {
        recall <- conf_matrix[2, 2] / sum(conf_matrix[2, ])
        precision <- conf_matrix[2, 2] / sum(conf_matrix[, 2])
        beta <- 0.5
        f_score <- (1 + beta^2) * (precision * recall) / (beta^2 * precision + recall)
      }
      
      return(list(precision = precision, recall = recall, f0.5 = f_score))
    }
    
    # Predict on validation set and calculate metrics
    valid_pred <- h2o.predict(model, valid_h2o)
    valid_labels <- as.vector(valid_h2o$label)
    valid_pred_labels <- as.vector(valid_pred$predict)
    valid_metrics <- calculate_metrics(valid_pred_labels, valid_labels)
    valid_precision_values <- c(valid_precision_values, valid_metrics$precision)
    valid_recall_values <- c(valid_recall_values, valid_metrics$recall)
    valid_f0.5_values <- c(valid_f0.5_values, valid_metrics$f0.5)
  }
  
  # Create data frames for plotting
  valid_metrics_df <- data.frame(
    TrainingSize = rep(training_sizes, each = 3),
    Metric = rep(c("Precision", "Recall", "F0.5 Score"), times = length(training_sizes)),
    Value = c(valid_precision_values, valid_recall_values, valid_f0.5_values),
    Dataset = "Validation"
  )
  
  # Plot learning curves with non-scientific notation
  p <- ggplot(valid_metrics_df, aes(x = TrainingSize, y = Value, color = Metric)) +
    geom_line() +
    scale_x_continuous(labels = scales::comma) +  # Use comma to avoid scientific notation
    labs(
      title = "Learning Curve",
      x = "Training Size",
      y = "Metric Value",
      color = "Metric"
    ) +
    scale_color_manual(values = c(
      "Precision" = "blue",
      "Recall" = "red",
      "F0.5 Score" = "green"
    )) +
    theme_minimal()
  
  print(p)
  
  h2o.saveModel(best_model, path = "./", force = TRUE)
  
  return(aml_object = automl_models)
  }

# Example usage
# Replace with your actual training and validation data
# train_data <- your_train_data
# valid_data <- your_valid_data
# result <- train_model_with_learning_curves(train_data, valid_data)
