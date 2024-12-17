library(ForestForesight)

# load data
data("countries")
countries <- terra::vect(countries)
groups <- unique(countries$group)
ff_folder <- "D:/ff-dev/results"


t <- 1
# train 1 #
### Train models on 2023 2024 including all features ###
for (group in groups[5:length(groups)]) {
  print(paste0("starting on group: ", group, " (", t, " from ", length(groups), ") "))
  t <- t + 1
  shape <- countries[countries$group == group]
  if (!dir.exists(paste0("D:/ff-dev/results/experimentation/mlflow/models_20241202/", group))) {
    dir.create(paste0("D:/ff-dev/results/experimentation/mlflow/models_20241202/", group),recursive = T)
  }
  # if (!dir.exists(paste0("D:/ff-dev/results/experimentation/mlflow/accuracy_20241202/", group))) {
  #   dir.create(paste0("D:/ff-dev/results/experimentation/mlflow/accuracy_20241202/", group))
  # }
  # Train and predict large model
  print("Train and predict large model")
  ff_run(
    shape = shape,
    ff_folder = ff_folder,
    train_dates = daterange("2023-06-01", "2024-05-01"),
    #trained_model = paste0("D:/ff-dev/results/experimentation/mlflow/models_20241202/",
    #                      group, "/", group, "_2022_large.model"),
    # prediction_dates = daterange("2023-06-01", "2024-05-01"),
    save_path = paste0("D:/ff-dev/results/experimentation/mlflow/models_20241202/",
                       group, "/", group, "_current_large.model"),
    #accuracy_csv = paste0("D:/ff-dev/results/experimentation/mlflow/accuracy_20241202/",
    #                      group, "/", group, "_2022_large.csv"),
    #importance_csv = "D:/ff-dev/results/experimentation/mlflow/importance_2022_large.csv",
    validation = TRUE,
    verbose = TRUE
  )
  # # train and predict small model
  # print("Train and predict small model")
  # importance <- read.csv("D:/ff-dev/results/experimentation/mlflow/importance_2022_large.csv", header = TRUE)
  # importance_group <- importance[importance$model_name == paste0(group,"_2022_large"), ]
  # num_features <- min(which(cumsum(importance_group$importance) > (0.95 * sum(importance_group$importance))))
  # print(paste0("starting on small models group: ", group, "using ", num_features, " features"))
  # features_sel <- importance$feature[1:num_features]
  # ff_run(
  #   shape = shape,
  #   ff_folder = ff_folder,
  #   ff_prep_params = list(inc_features = features_sel),
  #   train_dates = daterange("2022-01-01", "2022-12-01"),
  #   prediction_dates = daterange("2023-06-01", "2024-05-01"),
  #   save_path = paste0("D:/ff-dev/results/experimentation/mlflow/models_20241202/",
  #                      group, "/", group, "_2022_small.model"),
  #   accuracy_csv = paste0("D:/ff-dev/results/experimentation/mlflow/accuracy_20241202/",
  #                         group, "/", group, "_2022_small.csv"),
  #   importance_csv = "D:/ff-dev/results/experimentation/mlflow/importance_2022_small.csv",
  #   validation = TRUE,
  #   verbose = TRUE
  # )
}
