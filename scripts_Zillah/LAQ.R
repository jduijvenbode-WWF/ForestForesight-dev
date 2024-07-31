
## set environment ##

library(ForestForesight)
data("gfw_tiles")
gfw_tiles = vect(gfw_tiles)
data("countries")
countries = vect(countries)
dates = daterange("2023-06-01","2023-12-01")

for (date in dates) {
  for (country in countries) {
    amounts = rast(paste0("D:/ff-dev/predictionsZillah/amountPred/", country,'/', country ,'_', date, "_amountPrediction.tif"))
    confidence = rast(paste0("D:/ff-dev/results/predictions/", country,"/",country, "_", date, ".tif"))
    LAQ = amounts * confidence # calculate the likelihood adjusted confidence
    if (!dir.exists(file.path("D:/ff-dev/predictionsZillah/LAQ/",country))) {dir.create(file.path("D:/ff-dev/predictionsZillah/LAQ/",country))}
    writeRaster(LAQ, paste0("D:/ff-dev/predictionsZillah/LAQ/", country,'/', country ,'_', date, "_LAQ.tif"), overwrite=T )

    # get groundtruth per country
    tiles = gfw_tiles[countries[countries$iso3 == country],]$tile_id
    raslist <- list()
    for (tile in tiles) {
      gt_tile = rast(paste0("D:/ff-dev/results/preprocessed/groundtruth/", tile,"/", tile,"_", date,"_groundtruth6m"))
  }
}
