
library(ForestForesight)
# load data
data("countries")
countries <- terra::vect(countries)
groups = unique(countries$group)
ff_folder = "D:/ff-dev/results"
t = 35
prediction_date = "2024-08-01"

### Train models including all features ###

for (group in groups[35:length(groups)]) {
  print(paste0("starting on group: ", group , " (", t, " from ", length(groups),") " ))
  t = t + 1
  shape = countries[countries$group == group]
  ff_run(shape = shape,
          ff_folder = ff_folder,
          train_start = "2023-01-01",
          train_end = "2023-12-01",
          save_path = paste0("D:/ff-dev/results/models/", group,"/", group,".model"),
          importance_csv = "D:/ff-dev/results/accuracy_analysis/importance.csv",
          verbose = T)
}

### TRAIN SMALL MODELS USING the main features per group (cumulative 95% features importance) ###

importance = read.csv(paste0("D:/ff-dev/results/accuracy_analysis/","importance.csv"), header = F, col.names = c("group", "feature", "rank", "importance"))
t = 35
for (group in groups[35:45]) {
  importance_group = importance[importance$group == group,]
  num_features = min(which(cumsum(importance_group$importance) > (0.95*sum(importance_group$importance))))
  print(paste0("starting on group: ", group , " (", t, " from ", length(groups),") using ", num_features , " features" ))
  features_sel = importance$feature[1:num_features]
  t = t + 1
  shape = countries[countries$group == group]
  ff_run(shape = shape,
         ff_folder = ff_folder,
         ff_prep_params =  list(inc_features = features_sel),
         train_start = "2023-01-01",
         train_end = "2023-12-01",
         save_path = paste0("D:/ff-dev/results/models/", group,"/", group,"_small.model"),
         importance_csv = "D:/ff-dev/results/accuracy_analysis/importance_small.csv",
         verbose = T,
         autoscale_sample = T)
}

### Make predictions ####

t = 76
for (country in countries$iso3[76]) {
  print(paste0("starting on country: ", country, " (", t, " from ", length(countries$iso3),") " ))
  t=t+1
  group = countries$group[countries$iso3 == country]
  trained_model = paste0("D:/ff-dev/results/models/", group,"/", group,"_small.model")
  ff_run(country = country,
         ff_folder = ff_folder,
         prediction_dates = prediction_date,
         save_path_predictions = paste0("D:/ff-dev/results/predictions/",country, '/', country, "_",prediction_date, ".tif"),
         trained_model = trained_model)
}


### Polygonize ###

