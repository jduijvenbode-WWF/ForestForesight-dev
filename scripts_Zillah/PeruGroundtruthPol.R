library(ForestForesight)

# folder with the shape file
folder = "D:/ff-dev/predictionsZillah/Peru" #change to the folder with you shape files

# If needed Sync data from Peru
# ff_sync(paste0(folder,"/data/"), identifier = "PER")

# get the shapes
shapes = vect(paste0(folder,"/MonitoreoDeforestacionAcumulado.shp"))

# get range of dates
dates_shapes = sort(unique(shapes$md_fecimg))
print(dates_shapes)

# Select dates to loop over
# Based on data availability (A half year of monthly monitoring)
dates = daterange("2020-01-01","2023-01-01")
# get tiles to loop over (groundtruth data should be on a tile level )
tiles = dir(paste0(folder,"/data/preprocessed/groundtruth"), full.names = F)
nt=0
for (tile in tiles) {
  nt=nt+1
  template_rast = rast(paste0("D://ff-dev/predictionsZillah/Peru/data/preprocessed/groundtruth/", tile, "/", tile, "_2021-01-01_groundtruth6m.tif"))
  template_rast[] <- 1
  # Ensure `sel_shapes` and `template_rast` have the same CRS
  shapes <- terra:project(shapes, crs(template_rast))
  t=0
  for (date in dates) {
    t=t+1
    print(paste("starting on tile:", tile, "(", nt ,"/", length(tiles) ,") and date :", date, "(", t ,"/", length(dates) ,")" ))
    end_date =  as.Date(date) + months(6)
    # select all dates the half year after date of interest
    sel_dates_shapes = dates_shapes[as.Date(dates_shapes) >= as.Date(date) & as.Date(dates_shapes) < end_date]

    # I got some problems with the rasterization, thats why I added the buffer. Still feels like this is not the perfect solution.
    sel_shapes = aggregate(shapes[shapes$md_fecimg %in% sel_dates_shapes, ])
    sel_shapes_simplified <- simplifyGeom(sel_shapes, tolerance = 10)
    sel_shapes_buffered <- buffer(sel_shapes_simplified, 600)

    # rasterize shape file
    gt_rast = rasterize(sel_shapes_buffered, template_rast, background = 0, touches = TRUE, value = 1)
    output_path <- paste0(folder, "/data/preprocessed/groundtruth/", tile, "/", tile, "_",date, "_groundtruth6mshapes.tif")
    writeRaster(gt_rast, output_path, overwrite = TRUE)
  }
}

# check the ground truth for a small area (for last tile and date)
t_ext= ext(-75, -73,-13,-11)
plot(t_ext)
plot(gt_rast, add=T)
plot(sel_shapes_buffered, add=T)

## Test new ground truth ##

dir.create(path = paste0(folder, "/predictions"))

## train new model
# for now the model is trained for Peru,
# if you use shape instead of country you could train and predict only within the national parks
ff_run(country = "PER",
       ff_folder = paste0(folder,"/data"),
       train_dates = daterange("2021-01-01","2021-12-01"),
       ff_prep_params = list(groundtruth_pattern = "groundtruth6mshapes"),
       autoscale_sample = T,
       prediction_dates = daterange("2022-06-01","2023-01-01"),
       save_path = paste0(folder,"/test.model"),
       importance_csv = paste0(folder,"/importance.csv"),
       save_path_predictions = paste0(folder, "/predictions/Test.tif"),
       accuracy_csv =  paste0(folder,"/accuracy.csv"),
       verbose = T)

## when you use a trained model
ff_run(country = "PER",
       ff_folder = paste0(folder,"/data"),
       ff_prep_params = list(groundtruth_pattern = "groundtruth6mshapes"),
       autoscale_sample = T,
       prediction_dates = daterange("2022-06-01","2023-01-01"),
       trained_model =  paste0(folder,"/test.model"),
       importance_csv = paste0(folder,"/importance.csv"),
       save_path_predictions = paste0(folder, "/predictions/Test.tif"),
       accuracy_csv =  paste0(folder,"/accuracy.csv"),
       verbose = T)

# Is it fair to train a model based on partially available ground truth?
# With the polygons as ground truth we are only sure of these actuals but outside the polygons we dont now if there is deforestation or not
# also the accuracy csv will not make sense cause you dont have all grountruth values
# Best to combine the current groundtruth from GFW with the polygon ground truth
# e.g. only train the model on the data points where both groundtruths agree

