
library(ForestForesight)

data("countries")
countries <- vect(countries)
groups = unique(countries$group)


# Train model combined
shape = countries[which(countries$group %in% groups[1:8])]
ff_run(shape = shape,
       ff_folder = ff_folder,
       train_start = "2023-01-01",
       train_end = "2023-12-01",
       save_path = paste0("D:/ff-dev/results/experimentation/combined_8_groups.model"),
       verbose = T,
       autoscale_sample = T,
       fltr_features = "initialforestcover",
       fltr_condition = ">0")


## TEST MODELS PER COUNTRY ##


for (group in groups[1:8]) {
  for (country in countries$iso3[countries$group == group]) {
    ff_run(country = country,
           prediction_dates = daterange("2023-02-01", "2024-02-01"),
           ff_folder = "D:/ff-dev/results",
           fltr_features = "initialforestcover",
           fltr_condition = ">0",
           accuracy_csv = "D:/ff-dev/results/experimentation/size_sensitivity/CombinedModel.csv",
           verbose = T,
           trained_model = "D:/ff-dev/results/experimentation/combined_8_groups.model",
    )
  }
}


# Get feature importance
xgb_model= xgb.load( "D:/ff-dev/results/experimentation/combined_8_groups.model")
feature_names <- get(load("D:/ff-dev/results/experimentation/combined_8_groups.rda"))
importance_matrix <- xgb.importance(model = xgb_model)

importance_matrix$fnum = as.numeric(gsub("f","",importance_matrix$Feature)) + 1
importance_matrix$Feature = feature_names[importance_matrix$fnum]
print(importance_matrix)

# Plot feature importance
xgb.plot.importance(importance_matrix)

ggplot(importance_matrix, aes(x = reorder(Feature, Gain), y = Gain)) +
  geom_bar(stat = "identity") +
  coord_flip() +
  theme_minimal() +
  labs(x = "Features", y = "Gain", title = "Feature Importance in XGBoost Model")

