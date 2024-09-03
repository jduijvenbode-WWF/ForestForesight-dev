library(rBayesianOptimization)
library(xgboost)
library(ForestForesight)
ff_optimizer <- function(ff_folder, shape = NULL, country = NULL,
                                  train_dates, val_dates,
                                  #prediction_date,
                                  bounds = list(eta = c(0.01, 0.3),
                                                nrounds = c(50, 500),
                                                max_depth = c(3, 10),
                                                subsample = c(0.5, 1),
                                                gamma = c(0.01,1),
                                                min_child_weight = c(1,10)),
                                  init_points = 5, n_iter = 25, acq = "ucb", kappa = 2.576,
                                  ff_prep_params = list(), ff_train_params = list(),
                                  verbose = TRUE) {

  # Prepare data using ff_prep
  prep_params <- c(list(datafolder = ff_folder, shape = shape, country = country,
                        dates = train_dates), ff_prep_params)
  val_params <- c(list(datafolder = ff_folder, shape = shape, country = country,
                                  dates = val_dates), ff_prep_params)
  train_data <- do.call(ff_prep, prep_params)
  val_data <- do.call(ff_prep, val_params)

  # Objective function for Bayesian optimization
  xgb_cv_bayes <- function(eta, nrounds, max_depth, subsample,gamma,min_child_weight) {
    # Prepare the parameter list for ff_train
    train_params <- c(list(train_matrix = train_data$data_matrix,
                           validation_matrix = val_data$data_matrix,
                           nrounds = as.integer(round(nrounds)),
                           eta = eta,
                           max_depth = as.integer(round(max_depth)),
                           subsample = subsample,gamma=gamma,min_child_weight = min_child_weight,
                           verbose = FALSE), ff_train_params)

    # Train the model using ff_train
    model <- do.call(ff_train, train_params)

    # Get the best score (assuming AUCPR is used)
    best_score <- max(model$evaluation_log$eval_aucpr)

    return(list(Score = best_score, Pred = 0))
  }

  # Run Bayesian optimization
  opt_result <- BayesianOptimization(xgb_cv_bayes,
                                     bounds = bounds,
                                     init_points = init_points,
                                     n_iter = n_iter,
                                     acq = acq,
                                     kappa = kappa,
                                     verbose = verbose)

  # Extract best parameters
  best_params <- list(
    eta = opt_result$Best_Par["eta"],
    nrounds = as.integer(round(opt_result$Best_Par["nrounds"])),
    max_depth = as.integer(round(opt_result$Best_Par["max_depth"])),
    subsample = opt_result$Best_Par["subsample"],
    gamma = opt_result$Best_Par["gamma"],
    min_child_weight = opt_result$Best_Par["min_child_weight"]
  )

  # Train final model with best parameters
  final_train_params <- c(list(train_matrix = train_data$data_matrix,
                               validation_matrix = train_data$validation_matrix),
                          best_params,
                          ff_train_params)
  final_model <- do.call(ff_train, final_train_params)

  # Make prediction using ff_predict
  # prediction_data <- ff_prep(datafolder = ff_folder, shape = shape, country = country,
  #                            start = prediction_date, end = prediction_date)
  #
  # prediction <- ff_predict(model = final_model,
  #                          test_matrix = prediction_data$data_matrix,
  #                          indices = prediction_data$testindices,
  #                          templateraster = prediction_data$groundtruthraster)

  return(list(best_params = best_params,
              final_model = final_model,
              optimization_result = opt_result))
}
# shape=vect("D:/ff-dev/test_bayesian/XP&DHS_NP_Pilot.shp")
# result <- ff_bayesian_optimizer(
#   ff_folder = "D:/ff-dev/results/preprocessed/",
#   shape=shape,  # or use shape = your_shape_object
#   train_start = "2023-01-01",
#   train_end = "2023-06-01",
#   val_start = "2023-11-01",
#   val_end = "2023-12-01",
#   prediction_date = "2024-02-01",
#   bounds = list(
#     eta = c(0.15, 0.6),
#     nrounds = c(10, 500),
#     max_depth = c(2, 15),
#     subsample = c(0.1, 1),
#     gamma=c(0.01,1),
#     min_child_weight = c(1,10)
#   ),
#   init_points = 5,
#   n_iter = 50,
#   ff_prep_params = list(fltr_features = "initialforestcover", fltr_condition = ">0"),
#   verbose = TRUE
# )
#
# # The best parameters are in result$best_params
# # The final trained model is in result$final_model
# # The prediction is in result$prediction
# # To see the optimization process:
# print(result$optimization_result)
