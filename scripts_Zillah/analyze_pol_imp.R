# Load necessary libraries
library(terra)
library(dplyr)


threshold = 0.9
csvfile = paste0("D:/ff-dev/results/accuracy_analysis/SHAP", gsub("\\.", "", as.character(threshold)) ,".csv")

pol_imp = read.csv(csvfile)
data(degree_polygons,envir = environment())
pols <- terra::vect(degree_polygons)


countries_iso3 = unique(pol_imp$iso3)


for (country in countries_iso3){
  pols_country <- pols[which(pols$iso3 == country)]
  pol_imp_country = pol_imp[pol_imp$iso3 == country,]
 # pol_imp_country=pol_imp_country[!pol_imp_country$feature %in% c("timesinceloss", "smoothedtotal", "losslastyear", "lastmonth", "patchdensity", "confidence"), ]
  most_important_feature <- pol_imp_country %>%
    group_by(coordname) %>%
    filter(shap_value == max(shap_value)) %>%
    ungroup()
  pols_country= merge(pols_country, most_important_feature[2:4], by.x="coordname", by.y="coordname", first=T)

  png(paste0('D:/ff-dev/predictionsZillah/SHAPIMAGES/most_imp_0.9/', country, "_", threshold,'_SHAP.png') , height=300, width=600)
  plot(pols_country, "feature", main = countries$name[countries$iso3 == country])
  dev.off()


}
