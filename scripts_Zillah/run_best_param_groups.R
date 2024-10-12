library(ForestForesight)

data("countries")
countries <- vect(countries)
groups = unique(countries$group)

for (group in groups[1:15]) {
  for (country in countries$iso3[countries$group == group]){
    if(!dir.exists(paste0("D:/ff-dev/results/experimentation/predictions_param/",country))){
      dir.create(paste0("D:/ff-dev/results/experimentation/predictions_param/",country))
    }
    ff_run(country = country,
           prediction_dates = daterange("2023-02-01", "2024-02-01"),
           ff_folder = "D:/ff-dev/results",
           save_path_predictions = paste0("D:/ff-dev/results/experimentation/predictions_param/",country,"/", country, "_param.tif"),
           accuracy_csv = "D:/ff-dev/results/accuracy_analysis/param_optim_2023.csv",
           trained_model = paste0("D:/ff-dev/results/experimentation/models_param/", group, "bestparam.model"),
           verbose = T
    )
  }

}
