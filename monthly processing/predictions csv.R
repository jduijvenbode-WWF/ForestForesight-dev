setwd("D:/ff-dev/results")
library(ForestForesight)
groundtruths=list.files(path="preprocessed/groundtruth",pattern="6m",recursive=T,full.names = T)
forestmasks=list.files(path="preprocessed/input",pattern="initialforestcover",recursive=T,full.names = T)
predictions=list.files(path="predictions",pattern="tif$",recursive=T,full.names = T)
validdate=daterange("2021-01-01",Sys.Date())
validdate=validdate[1:(length(validdate)-6)]
predictions=predictions[unlist(sapply(predictions,function(x) substr(x,21,30) %in% validdate))]
countries=vect(get(data(countries)))
gfw_tiles=vect(get(data(gfw_tiles)))
predictions=c(predictions[grep("SUR",predictions)],predictions[-grep("SUR",predictions)])
for(prediction in predictions[1:length(predictions)]) {
  tryCatch({
    cat(prediction,"\n")
    date = substr(prediction, 21, 30)
    predras = rast(prediction)
    tiles = gfw_tiles[countries[countries$iso3 == basename(dirname(prediction))]]$tile_id
    groundtruth_selected = groundtruths[grep(date, groundtruths)]
    groundtruth_selected = groundtruth_selected[which(basename(dirname(groundtruth_selected)) %in% tiles)]
    raslist = sapply(groundtruth_selected, function(x) rast(x))
    raslist = unname(raslist)
    if(length(raslist) == 1) {
      groundtruthras = crop(rast(raslist), predras)
    } else {
      groundtruthras = crop(do.call(raster::merge, raslist), predras)
    }
    forestmasks_selected = forestmasks[which(basename(dirname(forestmasks)) %in% tiles)]
    raslist = sapply(forestmasks_selected, function(x) rast(x))
    raslist = unname(raslist)
    if(length(raslist) == 1) {
      forestmasksras = crop(rast(raslist), predras)
    } else {
      forestmasksras = crop(do.call(raster::merge, raslist), predras)
    }
    ff_analyze(predictions = predras > 0.5,
               groundtruth = groundtruthras > 0,
               forestmask = forestmasksras > 0,
               csvfile = "D:/ff-dev/results/accuracy_analysis/predictions.csv",
               append = T,
               date = date,
               verbose = T)
  },
  error = function(e) {
    # Write the failed prediction path and error message to file
    write(paste0(prediction, " - Error: ", e$message),
          file = "D:/ff-dev/incorrect.txt",
          append = TRUE)
    # Print error message to console
    cat("Error processing", prediction, ":", e$message, "\n")
  })
}
