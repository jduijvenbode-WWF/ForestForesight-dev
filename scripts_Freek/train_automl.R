library(caret)
library(doParallel)
library(ROCR)
library(e1071)
library(ggplot2)
library(h2o)

# Train with automl
train_model_with_confusion <- function(train_data, valid_data, save_model = FALSE, max_models = 15, max_cores = 8) {
  h2o.init(nthreads = 8)

  #cl <- makeCluster(max_cores)
  #registerDoParallel(cl)
  cat(sprintf("Using %d CPU cores for parallel processing\n", max_cores))

  x_train <- train_data$data_matrix$features
  y_train <- factor(train_data$data_matrix$label, levels = c(0, 1))
  levels(y_train) <- c("not_deforested", "deforested")

  x_validation <- valid_data$validation_matrix$features
  y_validation <- factor(valid_data$validation_matrix$label, levels = c(0, 1))
  levels(y_validation) <- c("not_deforested", "deforested")

  train_data <- cbind(x_train, label = y_train)
  valid_data <- cbind(x_validation, label = y_validation)

  train_h2o <- as.h2o(train_data)
  valid_h2o <- as.h2o(valid_data)

  train_h2o$label <- as.factor(train_h2o$label)
  valid_h2o$label <- as.factor(valid_h2o$label)

  if (is.null(colnames(x_train)) || is.null(colnames(x_validation))) {
    stop("Column names are missing from the training or validation datasets.")
  }

  cat("Training model...\n")
  old_time <- Sys.time()

  automl_models <- h2o.automl(
    x = names(train_h2o)[-which(names(train_h2o) == "label")],
    y = "label",
    training_frame = train_h2o,
    validation_frame = valid_h2o,
    max_models = max_models,
    max_runtime_secs = 3600,
    seed = 123
  )

  cat("Model trained\n")
  current_time <- Sys.time()
  train_time <- as.numeric(difftime(current_time, old_time, units = "secs"))

  hours <- floor(train_time / 3600)
  minutes <- floor((train_time %% 3600) / 60)
  seconds <- (train_time %% 3600) %% 60

  cat(sprintf("Training time was Hours: %d, Minutes: %d, Seconds: %f\n", hours, minutes, seconds))

  leaderboard <- h2o.get_leaderboard(automl_models, extra_columns = "ALL")
  print(leaderboard)

  if (save_model != FALSE) {
    model_filename <- paste0(save_model, ".rds")
    saveRDS(list(automl_models = automl_models), file = model_filename)
    cat(sprintf("Model saved as %s\n", model_filename))
  }

  return(aml_object = automl_models)
}
