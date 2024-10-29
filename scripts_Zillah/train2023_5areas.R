
library(ForestForesight)
# load data
data("countries")
countries <- terra::vect(countries)
ff_folder = "D:/ff-dev/results"
study_areas = c("Guaviare", "Laos", "Gabon", "Madre de dios", "Tahura")
gadm = vect("D:/ff-dev/results/contextualization/GADM.gpkg")
wdpa =  vect("D:/ff-dev/results/contextualization/WDPA.gpkg")

madre_de_dios_boundary <- aggregate(gadm[gadm$province == "Madre de Dios"])
madreDeDios_shape = crop(wdpa, madre_de_dios_boundary)

guaviare_boundary <- aggregate(gadm[gadm$province == "Guaviare"])
guaviare_shape = crop(wdpa, guaviare_boundary)


laos_shape = vect("D:/ff-dev/predictionsZillah/studyAreas/shapes/Pilot_NP_LAOS/XP&DHS_NP_Pilot.shp")
laos_shape <- project(laos_shape, countries)

gabon_shape = vect("D:/ff-dev/predictionsZillah/studyAreas/shapes/09_Gabon_Mining_Prospecting/Permis_de_recherche_miner.shp")
gabon_shape <- project(gabon_shape, countries)
tahura_shape = vect("D:/ff-dev/predictionsZillah/studyAreas/shapes/Tahura_indonesia/Tahura.shp")
tahura_shape <- project(tahura_shape, countries)

shapes = c(guaviare_shape,laos_shape,gabon_shape,madreDeDios_shape,tahura_shape)

### Train models and make predictions ###
# Longer training (2 years), to mitigate small area sizes
for (i in c(1,4)) {
  study_area = study_areas[i]
  print(paste0("starting on: ", study_area ))
  shape = shapes[i]
  ff_run(shape = shape,
         ff_folder = ff_folder,
         train_dates = daterange("2022-01-01", "2023-12-01"),
         autoscale_sample = T,
         prediction_dates = c(daterange("2023-02-01", "2024-02-01"), "2024-10-01"),
         validation_dates = daterange("2021-01-01", "2021-12-01"),
         save_path = paste0("D:/ff-dev/predictionsZillah/studyAreas/models/",study_area,".model"),
         importance_csv = paste0("D:/ff-dev/predictionsZillah/studyAreas/importance_", study_area,".csv"),
         save_path_predictions = paste0("D:/ff-dev/predictionsZillah/studyAreas/predictions/",study_area, '/', study_area,".tif"),
         accuracy_csv = paste0("D:/ff-dev/predictionsZillah/studyAreas/accuracy_", study_area, ".csv"),
         verbose = T)
}

# ## make prediction october
# for (i in c(1,4)) {
#   study_area = study_areas[i]
#   print(paste0("starting on: ", study_area ))
#   shape = shapes[i]
#   ff_run(shape = shape,
#          ff_folder = ff_folder,
#          prediction_dates = "2024-10-01",
#          trained_model = paste0("D:/ff-dev/predictionsZillah/studyAreas/models/",study_area,".model"),
#          save_path_predictions = paste0("D:/ff-dev/predictionsZillah/studyAreas/predictions/",study_area, '/', study_area,"_2024-10-01.tif"),
#          verbose = T)
# }


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

### Accuracy reports ###
for (i in seq(length(study_areas))) {
  study_area = study_areas[i]
  ff_importance(paste0("D:/ff-dev/predictionsZillah/studyAreas/models/",study_area,".model"),
                output_csv =  paste0("D:/ff-dev/predictionsZillah/studyAreas/importance_", study_area,".csv"),append = F
                       )
  ff_accuracyreport(accuracy_paths = paste0("D:/ff-dev/predictionsZillah/studyAreas/accuracy_", study_area, ".csv"),
                    importance_paths = paste0("D:/ff-dev/predictionsZillah/studyAreas/importance_", study_area,".csv"),
                    output_path = paste0("D:/ff-dev/predictionsZillah/studyAreas/accuracyreport_", study_area,".png"),
                    title = paste("Accuracy Analysis: Forest Foresight ", study_area))
                    }
# for (i in seq(length(study_areas))) {
#   study_area = study_areas[i]
#   rm_files= list.files(paste0("D:/ff-dev/predictionsZillah/studyAreas/predictions/", study_area[1]),pattern = "risk.shp", full.names = T)
#   file.remove(rm_files)}

### Polygonize ###
for (i in c(1,4)) {
  study_area = study_areas[i]
  files = list.files(paste0("D:/ff-dev/predictionsZillah/studyAreas/predictions/", study_area),pattern = ".tif", full.names = T)
  for (file in files){
    colras = rast(file)
    medium_risk <- ff_polygonize(colras, sub("\\.tif$", "_mediumrisk.shp", file), threshold = "medium", verbose = T, calc_max = T)
    high_risk <- ff_polygonize(colras, sub("\\.tif$", "_highrisk.shp",
                                           file), threshold = "high", verbose=T, contain_polygons = medium_risk, calc_max = T)
    highest_risk <- ff_polygonize(colras, sub("\\.tif$", "_highestrisk.shp",file), threshold = "very high", verbose = T, calc_max = T, contain_polygons = high_risk)
  }
}

### Polygonize groundtruth ###

for (i in seq(length(study_areas))) {
  study_area = study_areas[i]
  shape = shapes[i]
  for (date in daterange("2023-02-01","2024-02-02")){
    blras = crop(ForestForesight::get_raster(datafolder = "D:/ff-dev/results/preprocessed/input/",
                                         feature = "lastsixmonths",date = date, shape = shape, return_raster = T), shape, mask=T)
    colras= rast((paste0("D:/ff-dev/predictionsZillah/studyAreas/predictions/", study_area,"/", study_area, "_", date, ".tif")))
    th_medium = as.numeric(terra::global(colras < 0.5, fun = "mean",na.rm=T))
    th_bl_medium = quantile(as.matrix(blras), th_medium, na.rm=T)
    th_high = as.numeric(terra::global(blras< quantile(blras[blras > th_bl_medium], 0.5), fun = "mean",na.rm=T))
    th_bl_high = quantile(as.matrix(blras), th_high, na.rm=T)
    th_highest = as.numeric(terra::global(blras< quantile(blras[blras > th_bl_medium], 0.75), fun = "mean",na.rm=T))
    th_bl_highest = quantile(as.matrix(blras), th_highest, na.rm=T)

    medium_risk <- ff_polygonize(blras, paste0("D:/ff-dev/results/experimentation/studyAreas/baseline/", study_area, "_", date, "_mediumrisk.shp"), threshold = th_bl_medium, verbose = T, calc_max = T)
    high_risk <- ff_polygonize(blras, paste0("D:/ff-dev/results/experimentation/studyAreas/baseline/", study_area, "_", date, "_highrisk.shp")
                                           , threshold =  th_bl_high, verbose=T, contain_polygons = medium_risk, calc_max = T)
    highest_risk <- ff_polygonize(blras, paste0("D:/ff-dev/results/experimentation/studyAreas/baseline/", study_area, "_", date, "_highestrisk.shp"), threshold =  th_bl_highest, verbose = T, calc_max = T, contain_polygons = high_risk)
  }

}


## get accuracies ##
setwd("D:/ff-dev/predictionsZillah/studyAreas/predictions/")
dirs = basename(list.dirs(getwd())[2:6])
riskclasses = c("mediumrisk","highrisk","highestrisk")

if (exists("allres")){rm(allres)}
for (country in dirs){
  for(y in daterange("2023-02-01", "2024-02-01")){
    for(risk in riskclasses){
      if (file.exists(paste0(country,"/",country,"_",y,"_",risk,".shp"))){
        res=vect(paste0(country,"/",country,"_",y,"_",risk,".shp"))
        res$date=y
        res$landscape=country
        res$risk=risk

        groundtruth = ForestForesight::get_raster(datafolder = "D:/ff-dev/results/preprocessed/groundtruth",
                                                  feature = "groundtruth6m",date = y, shape = res, return_raster = T) > 0
        forestmask = ForestForesight::get_raster(datafolder = "D:/ff-dev/results/preprocessed/input/",
                                                 feature = "initialforestcover",date = y, shape = res, return_raster = T) > 0
        preds=rast(paste0(country,"/",country,"_",y,".tif"))
        forestmask=crop(forestmask,preds)
        groundtruth=crop(groundtruth,preds)
        preds = crop(preds,groundtruth)
        analysis_pol = ff_analyze(predictions = preds > 0.5,
                                  groundtruth = groundtruth*1,
                                  forestmask = forestmask*1,
                                  analysis_polygons = res,
                                  return_polygons = T,
                                  remove_empty = F,
                                  date = y,
                                  verbose = T )
        if(!exists("allres")){allres=analysis_pol}else{allres=rbind(allres,analysis_pol)}
        TP = sum(analysis_pol$TP, na.rm = T)
        FN = sum(analysis_pol$FN, na.rm = T)
        TN = sum(analysis_pol$TN, na.rm = T)
        FP = sum(analysis_pol$FP, na.rm = T)
        # metric 1: percentage of polygons where tp>0
        metric1 = length(analysis_pol[analysis_pol$TP>0|analysis_pol$FN>0]) / length(analysis_pol)*100
        # metric 2: average of TP+FN / (TP+FP+TN+FN)
        metric2 = (TP + FN) / (TP + FN + TN + FP)
        precision = TP  / (TP + FP)
        recall =  TP / (TP + FN)
        F05 = 1.25 * precision * recall / (0.25*precision + recall)

        if(!exists("alldat")){alldat=data.frame("landscape" = country,"risklevel" = risk,"date" = y,
                                                "metric1"=metric1,"metric2"=metric2, "precision" = precision,"recall"= recall, "f05"= F05 )}else{
                                                  alldat=rbind(alldat,c(country,risk,y,metric1,metric2, precision, recall, F05))

      }

      }
    }
  }
}

## predictions no groundtruth

if(exists("allres")){rm(allres)}
for (country in dirs) {
  shape = aggregate(shapes[which(study_areas == country)][,0])
  shape_r = vect(round(geom(shape),4), type="polygons", crs=crs(shape))
  shape_r = simplifyGeom(shape_r, tolerance = 0.0004)
  for(y in "2024-10-01"){
    for(risk in riskclasses){
      res = vect( paste0(country,"/",country,"_",y,"_",risk,".shp"))
      res = simplifyGeom(res, tolerance = 0.0004)
      plot(shape_r)
      plot(res, add = T, col = "red")
      shape_r$date=y
      shape_r$landscape= country
      shape_r$risk=risk
      shape_r$styling = "study area"
      res$date=y
      res$landscape = country
      res$risk = risk
      res$styling = risk
      if(!exists("allres")){allres=rbind(res, shape_r)}else{allres=rbind(allres,res, shape_r)}
      }
    }
  }

## Add wkt to allres, dataframe maken en dan csv  ##
## add landscape_risk_date

# Convert to sf object
polygons_sf <- st_as_sf(allres)
# Create WKT column
polygons_sf$wkt <- st_as_text(polygons_sf$geometry)
# Create landscape_risk_date column
# polygons_sf$landscape_risk_date <- paste(
#   polygons_sf$landscape,
#   polygons_sf$risk,
#   polygons_sf$date,
#   sep = "_"
# )
# Remove geometry column
polygons_sf <- st_drop_geometry(polygons_sf)
# Write to CSV
write.csv(polygons_sf, "pred_polygons_oct.csv", row.names = FALSE)


alldat$landscape_risk_date <- paste(alldat$landscape, alldat$risklevel, alldat$date, sep = "_")
write.csv(alldat, "overall_metrices_05.csv", row.names = FALSE)

