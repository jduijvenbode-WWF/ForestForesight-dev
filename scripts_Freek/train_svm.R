library(caret)
library(doParallel)
library(ROCR)
library(e1071)
library(ggplot2)

customPrSummary <- function(data, lev = NULL, model = NULL) {
  # Assuming binary classification with levels
  if (is.null(lev)) {
    lev <- levels(data$obs)
  }
  # Setting the positive class "deforested"
  reference <- lev[2]

  # Calculate Precision and Recall
  precision <- caret::posPredValue(data$pred, data$obs, positive = reference)
  recall <- caret::sensitivity(data$pred, data$obs, positive = reference)

  # Calculate F0.5 Score
  F05 <- (1 + 0.5^2) * (precision * recall) / ((0.5^2 * precision) + recall)

  # Return a named list including F0.5
  out <- c(Precision = precision, Recall = recall, F0_5 = F05)
  out[is.na(out)] <- 0  # Handling NaN or NA values
  names(out) <- c("Precision", "Recall", "F0.5")
  return(out)
}

train_model <- function(train_data, valid_data, save_model = FALSE) {
  less_cores = 16
  max_cores <- parallel::detectCores(logical = TRUE)
  cl <- makeCluster(max_cores - less_cores)
  registerDoParallel(cl)
  cat(sprintf("Using %d CPU cores for parallel processing\n", (max_cores - less_cores)))

  # Preprocess the training and validation data without removing zero variance predictors
  preProcValues <- preProcess(train_data$data_matrix$features, method=c("center", "scale"))

  # Applying preprocessing to training and validation datasets
  x_train <- predict(preProcValues, train_data$data_matrix$features)
  y_train <- factor(train_data$data_matrix$label, levels = c(0, 1))
  levels(y_train) <- c("not_deforested", "deforested")

  x_validation <- predict(preProcValues, valid_data$validation_matrix$features)
  y_validation <- factor(valid_data$validation_matrix$label, levels = c(0, 1))
  levels(y_validation) <- c("not_deforested", "deforested")

  # Check again to ensure column names exist
  if (is.null(colnames(x_train)) || is.null(colnames(x_validation))) {
    stop("Column names are missing from the training or validation datasets.")
  }

  ctrl <- trainControl(method = "repeatedcv", number = 5, repeats = 1,
                       allowParallel=TRUE, savePredictions = "final",
                       classProbs = TRUE, summaryFunction=customPrSummary)

  cat("Training model...\n")

  # Capture and format the start time
  start_time <- format(Sys.time(), "%Y-%m-%d %H:%M:%S")

  # Print the formatted start time
  print(paste("Time started:", start_time))

  old_time <- Sys.time()
  model <- train(x = x_train, y = y_train, method = "svmPoly",
                 trControl = ctrl, metric='F0.5', tuneGrid=expand.grid(degree = c(1, 2, 3), scale = c(1, 2), C = c(0.5, 1)))

  cat("Model trained\n")
  current_time <- Sys.time()
  train_time <- as.numeric(difftime(current_time, old_time, units = "secs"))

  # Convert to hours, minutes, and seconds
  hours <- floor(train_time / 3600)
  minutes <- floor((train_time %% 3600) / 60)
  seconds <- (train_time %% 3600) %% 60

  # Output the results
  duration_train = sprintf("Training time was Hours: %d, Minutes: %d, Seconds: %f", hours, minutes, seconds)
  print(duration_train)

  if (save_model != FALSE) {
    model_filename <- paste0(save_model, ".rds")
    saveRDS(list(model = model, preProc = preProcValues, file = model_filename))
    cat(sprintf("Model saved as %s\n", model_filename))
  }

  if (!is.null(model$finalModel@SVindex)) {
    sv_indices <- model$finalModel@SVindex
    support_vectors <- x_train[sv_indices, ]
    feature_summary <- colSums(support_vectors)

    # Normalize to sum up to 100 for percentage calculation
    feature_importance <- feature_summary / sum(feature_summary) * 100

    # Adjust the outer margins to create more space for x-axis labels and the legend
    par(mar = c(4, 4, 4, 2) + 0.3)

    # Create bar plot
    bp <- barplot(feature_importance, main = "Feature Importance from Support Vectors",
                  col = 'blue', ylab="importance in percentage for prediction", ylim = c(0, 110), names.arg = "")

    # Add percentage labels above the bars
    text(x = bp, y = feature_importance + 1, label = sprintf("%.1f%%", feature_importance),
         pos = 3, cex = 0.8, col = "black")

    # Rotate x variables
    text(x = bp, y = -par("mar")[2], labels = colnames(support_vectors), srt = 45, adj = 1,
         xpd = TRUE, cex = 0.8)

  } else {
    cat("No support vector indices available.\n")
  }

  # Generate predictions on the validation dataset
  pred <- predict(model, newdata = x_validation)

  # Get values out of the confusion matrix
  print(confusionMatrix(y_validation, pred, positive = "deforested"))

  stopCluster(cl)
  registerDoSEQ()
  summary(model)

  return(model)
}
# train_data <- ff_prep(datafolder="D:/ff-dev/results/preprocessed", tiles="10S_060W", fltr_features="initialforestcover", fltr_condition='>0', validation_sample=0.5, sample_size=0.0035, exc_features=c("croplandcapacitybelow50p", "croplandcapacityover50p", "croplandcapacity100p"), label_threshold=1, start="2021-06-01", end="2022-05-01")
# valid_data <- ff_prep(datafolder="D:/ff-dev/results/preprocessed", tiles="10S_060W", fltr_features="initialforestcover", fltr_condition='>0', validation_sample=0.5, sample_size=0.007, exc_features=c("croplandcapacitybelow50p", "croplandcapacityover50p", "croplandcapacity100p"), label_threshold=1, start="2022-12-01", end="2023-05-01")
