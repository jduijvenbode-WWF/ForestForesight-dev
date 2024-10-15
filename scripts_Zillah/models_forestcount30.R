library(ForestForesight)

data("countries")
countries <- vect(countries)
groups = unique(countries$group)
ff_folder = "D:/ff-dev/results"
importance = read.csv(paste0("D:/ff-dev/results/accuracy_analysis/","importance.csv"), header = F, col.names = c("group", "feature", "rank", "importance"))
t = 1
for (group in groups[1:8]) {
  importance_group = importance[importance$group == group,]
  num_features = min(which(cumsum(importance_group$importance) > (0.95*sum(importance_group$importance))))
  print(paste0("starting on group: ", group , " (", t, " from ", length(groups),") using ", num_features , " features" ))
  features_sel = importance$feature[1:num_features]
  t = t + 1
  shape = countries[countries$group == group]
  ## TRAIN MODELS PER GROUP ##
  ff_run(shape = shape,
         ff_folder = ff_folder,
         ff_prep_params =  list(inc_features = features_sel),
         train_start = "2023-01-01",
         train_end = "2023-12-01",
         save_path = paste0("D:/ff-dev/results/experimentation/models_forestcount30/", group,"_small_fc30.model"),
         verbose = T,
         autoscale_sample = T,
         fltr_features = "initialforestcount30p",
         fltr_condition = ">0")
}


## TEST MODELS PER COUNTRY ##

prediction_date = daterange("2023-02-01", "2024-02-01")

for (group in groups[1:8]) {
  for (country in countries$iso3[countries$group == group]) {
    if (!dir.exists(paste0("D:/ff-dev/results/experimentation/predictions_TC30/",country))) {
      dir.create(paste0("D:/ff-dev/results/experimentation/predictions_TC30/",country))
    }
    ff_run(country = country,
           prediction_dates = daterange("2023-02-01", "2024-02-01"),
           ff_folder = "D:/ff-dev/results",
           fltr_features = "initialforestcount30p",
           fltr_condition = ">0",
           save_path_predictions = paste0("D:/ff-dev/results/experimentation/predictions_TC30/",country,"/", country, "_TC30.tif"),
           accuracy_csv = "D:/ff-dev/results/accuracy_analysis/TC30_2023.csv",
           verbose = T,
           trained_model = paste0("D:/ff-dev/results/experimentation/models_forestcount30/", group,"_small_fc30.model"),
    )
  }

}
