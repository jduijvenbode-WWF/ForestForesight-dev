## Optimize params per group ##


library(ForestForesight)
# load data
data("countries")
countries <- terra::vect(countries)
groups = unique(countries$group)
output_csv=  "D:/ff-dev/results/experimentation/paramPerGroup.csv"
t = 1
start=T
for (group in groups) {
  print(paste0("starting on group: ", group , " (", t, " from ", length(groups),") " ))
  t = t + 1
  shape = countries[countries$group == group]
  result <- ff_optimizer(
    ff_folder = "D:/ff-dev/results/preprocessed/",
    shape = shape,  # or use shape = your_shape_object
    train_dates = daterange("2023-01-01", "2023-12-01"),
    val_dates = daterange("2022-01-01", "2022-12-01")[seq(1,12,2)],
 # prediction_date = "2024-02-01",
    bounds = list(
      eta = c(0.01, 0.8),
      nrounds = c(10, 500),
      max_depth = c(2, 15),
      subsample = c(0.1, 1),
      gamma=c(0.01,1),
      min_child_weight = c(1,10)
    ),
    init_points = 5,
    n_iter = 50,
    ff_prep_params = list(fltr_features = "initialforestcover", fltr_condition = ">0"),
    verbose = TRUE
  )
  df= data.frame(result$best_params)
  df$group=group
  # Write to CSV
  write.table(df, file = output_csv, sep = ",", row.names = FALSE,
              col.names = start, append = !start)
  # save final model
  feature_names=result$final_model$feature_names
  xgb.save(result$final_model, paste0("D:/ff-dev/results/experimentation/models_param/", group, "bestparam.model"))
  save(feature_names,file = paste0("D:/ff-dev/results/experimentation/models_param/", group, "bestparam.rda"))
  start=F
}
