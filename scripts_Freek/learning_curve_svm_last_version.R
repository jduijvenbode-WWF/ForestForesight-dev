library(parallel)
library(doParallel)
library(caret)
library(ggplot2)
library(e1071) # for svm function

# Main function to train the model and process the learning curve
process_learning_curve <- function(train_data, valid_data, save_model = FALSE) {
  # Function to calculate F0.5 score
  calculate_f05 <- function(predictions, actuals, positive_label) {
    precision <- posPredValue(predictions, actuals, positive = positive_label)
    recall <- sensitivity(predictions, actuals, positive = positive_label)
    if (is.na(precision) || is.na(recall) || (precision + recall == 0)) {
      return(NaN)
    }
    F0.5 <- (1.25 * precision * recall) / (0.25 * precision + recall)
    return(F0.5)
  }
  
  # Function to calculate precision and recall
  calculate_metrics <- function(predictions, actuals, positive_label) {
    precision <- posPredValue(predictions, actuals, positive = positive_label)
    recall <- sensitivity(predictions, actuals, positive = positive_label)
    return(list(precision = precision, recall = recall))
  }
  
  # Detect the number of CPU cores
  max_cores <- parallel::detectCores(logical = TRUE)
  cl <- makeCluster(max_cores - 24)
  registerDoParallel(cl)
  cat(sprintf("Using %d CPU cores for parallel processing\n", max_cores-24))
  
  # Preprocess the training and validation data
  preProcValues <- preProcess(train_data$data_matrix$features, method = c("center", "scale"))
  
  # Applying preprocessing to training and validation datasets
  x_train <- predict(preProcValues, train_data$data_matrix$features)
  y_train <- factor(train_data$data_matrix$label, levels = c(0, 1))
  levels(y_train) <- c("not_deforested", "deforested")
  
  x_validation <- predict(preProcValues, valid_data$validation_matrix$features)
  y_validation <- factor(valid_data$validation_matrix$label, levels = c(0, 1))
  levels(y_validation) <- c("not_deforested", "deforested")
  
  # Set up training control
  train_control <- trainControl(
    method = "repeatedcv",
    number = 5,
    repeats = 1,
    allowParallel = FALSE,
    summaryFunction = function(data, lev = NULL, model = NULL) {
      F0.5 <- calculate_f05(data$pred, data$obs, "deforested")
      precision_recall <- calculate_metrics(data$pred, data$obs, "deforested")
      c(F0.5 = F0.5, Precision = precision_recall$precision, Recall = precision_recall$recall)
    },
    classProbs = TRUE
  )
  
  # Capture and format the start time
  start_time <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")
  print(paste("Time started:", start_time))
  
  # Initialize an empty data frame to store learning curve results
  learning_curve <- data.frame()
  
  # Create an index sequence for sampling
  set.seed(123) # Ensure reproducibility
  all_indices <- sample(1:nrow(x_train))
  
  current_model <- NULL
  
  # Loop through each training size
  for (fraction in seq(0.05, 1, by = 0.05)) {
    end_index <- floor(fraction * nrow(x_train))
    new_indices <- all_indices[1:end_index]
    new_data <- list(
      features = x_train[new_indices, ],
      labels = y_train[new_indices]
    )
    
    deforested_count <- sum(new_data$labels == "deforested")
    not_deforested_count <- sum(new_data$labels == "not_deforested")
    
    if (is.null(current_model)) {
      # Train the initial model
      current_model <- svm(new_data$features, new_data$labels, probability = TRUE)
    } else {
      # Retrain the model with additional data
      current_model <- svm(new_data$features, new_data$labels, probability = TRUE)
    }
    
    total_training_size <- end_index
    
    # Make predictions
    train_predictions <- predict(current_model, new_data$features)
    train_F0.5 <- calculate_f05(train_predictions, new_data$labels, "deforested")
    train_metrics <- calculate_metrics(train_predictions, new_data$labels, "deforested")
    
    validation_predictions <- predict(current_model, x_validation)
    validation_F0.5 <- calculate_f05(validation_predictions, y_validation, "deforested")
    validation_metrics <- calculate_metrics(validation_predictions, y_validation, "deforested")
    
    validation_deforested_count <- sum(y_validation == "deforested")
    validation_not_deforested_count <- sum(y_validation == "not_deforested")
    
    # Confusion matrices
    validation_confusion <- confusionMatrix(validation_predictions, y_validation)
    
    # Print an update after each model is trained
    cat(sprintf("Trained model with %.0f%% of the data. Training size: %d. Validation F0.5: %.4f\n",
                fraction * 100, total_training_size, validation_F0.5))
    cat(sprintf("Training set composition: deforested = %d, not deforested = %d\n", deforested_count, not_deforested_count))
    cat(sprintf("Validation set composition: deforested = %d, not deforested = %d\n", validation_deforested_count, validation_not_deforested_count))
    print(validation_confusion)
    
    # Store the results
    learning_curve <- rbind(learning_curve, data.frame(
      Training_Size = total_training_size,
      Validation_F0.5 = validation_F0.5,
      Validation_Precision = validation_metrics$precision,
      Validation_Recall = validation_metrics$recall
    ))
    
    # Remove large objects and trigger garbage collection
    rm(validation_predictions)
    gc()
  }
  
  print(learning_curve)
  
  p <- ggplot(learning_curve, aes(x = Training_Size)) +
    geom_line(aes(y = Validation_F0.5, color = "Validation F0.5 Score", linetype = "Validation F0.5 Score")) +
    geom_line(aes(y = Validation_Precision, color = "Validation Precision", linetype = "Validation Precision")) +
    geom_line(aes(y = Validation_Recall, color = "Validation Recall", linetype = "Validation Recall")) +
    labs(
      title = sprintf("Learning Curve %s", model_method_name),
      x = "Training Size",
      y = "F0.5-Score",
      color = "Metric",
      linetype = "Metric"
    ) +
    scale_color_manual(values = c(
      "Validation F0.5 Score" = "red",
      "Validation Precision" = "blue",
      "Validation Recall" = "green"
    )) +
    scale_linetype_manual(values = c(
      "Validation F0.5 Score" = "solid",
      "Validation Precision" = "solid",
      "Validation Recall" = "solid"
    )) +
    theme_minimal()
  
  print(p)
  
  # Stop the cluster
  stopCluster(cl)
  registerDoSEQ()
  
  # Return the learning curve data
  return(list(learning_curve = learning_curve))
}

# Example usage (replace with actual data)
# train_data <- list(data_matrix = list(features = train_features, label = train_labels))
# valid_data <- list(validation_matrix = list(features = valid_features, label = valid_labels))
# result <- process_learning_curve(train_data, valid_data)
