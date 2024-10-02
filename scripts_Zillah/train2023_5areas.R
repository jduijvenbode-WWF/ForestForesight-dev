
library(ForestForesight)
# load data
data("countries")
countries <- terra::vect(countries)
ff_folder = "D:/ff-dev/results"
study_areas = c("Guaviare", "Laos", "Gabon", "Madre de dios", "Tahura")
gadm = vect("D:/ff-dev/results/contextualization/GADM.gpkg")
wdpa =  vect("D:/ff-dev/results/contextualization/WDPA.gpkg")

guaviare_shape = wdpa[aggregate(gadm[gadm$province == "Guaviare"])]
madreDeDios_shape = wdpa[aggregate(gadm[gadm$province == "Madre de Dios"])]
laos_shape = vect("D:/ff-dev/predictionsZillah/studyAreas/shapes/Pilot_NP_LAOS/XP&DHS_NP_Pilot.shp")
laos_shape <- project(laos_shape, countries)
gabon_shape = vect("D:/ff-dev/predictionsZillah/studyAreas/shapes/09_Gabon_Mining_Prospecting/Permis_de_recherche_miner.shp")
gabon_shape <- project(gabon_shape, countries)
tahura_shape = vect("D:/ff-dev/predictionsZillah/studyAreas/shapes/Tahura_indonesia/Tahura.shp")
tahura_shape <- project(tahura_shape, countries)

shapes = c(guaviare_shape,laos_shape,gabon_shape,madreDeDios_shape,tahura_shape)

### Train models and make predictions ###
# Longer training (2 years), to mitigate small area sizes
for (i in seq(length(study_areas))) {
  study_area = study_areas[i]
  dir.create(paste0("D:/ff-dev/predictionsZillah/studyAreas/predictions/",study_area))
  print(paste0("starting on: ", study_area ))
  shape = shapes[i]
  ff_run(shape = shape,
         ff_folder = ff_folder,
         train_start = "2022-01-01",
         train_end = "2023-12-01",
         autoscale_sample = T,
         prediction_dates = daterange("2023-02-01", "2024-02-01"),
         validation_dates = daterange("2021-06-01", "2021-12-01"),
         save_path = paste0("D:/ff-dev/predictionsZillah/studyAreas/models/",study_area,".model"),
         importance_csv = paste0("D:/ff-dev/predictionsZillah/studyAreas/importance_", study_area,".csv"),
         save_path_predictions = paste0("D:/ff-dev/predictionsZillah/studyAreas/predictions/",study_area, '/', study_area,".tif"),
         accuracy_csv = paste0("D:/ff-dev/predictionsZillah/studyAreas/accuracy_", study_area, ".csv"),
         verbose = T)
}

## GET SCORES ##
res=matrix(nrow=3,ncol=5)
for(i in seq(length(study_areas))){
  study_area = study_areas[i]
  sinres=read.csv(paste0("D:/ff-dev/predictionsZillah/studyAreas/accuracy_", study_area, ".csv"))
  precision=sum(sinres$TP,na.rm=T)/(sum(sinres$TP,na.rm=T)+sum(sinres$FP,na.rm=T))
  recall=sum(sinres$TP,na.rm=T)/(sum(sinres$TP,na.rm=T)+sum(sinres$FN,na.rm=T))
  F05=1.25*precision*recall/(0.25*precision+recall)
  res[1,i]=precision
  res[2,i]=recall
  res[3,i]=F05
}
rownames(res)=c("precision", "recall","F05")
colnames(res)= study_areas
print(res)
write.csv(res, "D:/ff-dev/predictionsZillah/studyAreas/trainNewModels.csv" )



### Polygonize ###




