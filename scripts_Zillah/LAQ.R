
## set environment ##

library(ForestForesight)
data("gfw_tiles")
gfw_tiles = vect(gfw_tiles)
data("countries")
countries = vect(countries)
dates = daterange("2023-06-01","2023-12-01")


for (date in dates) {
  for (country in countries$iso3) {
    amounts = rast(paste0("D:/ff-dev/predictionsZillah/amountPred/", country,'/', country ,'_', date, "_amountPrediction.tif"))
    confidence = rast(paste0("D:/ff-dev/results/predictions/", country,"/",country, "_", date, ".tif"))
    LAQ = amounts * confidence # calculate the likelihood adjusted confidence
    if (!dir.exists(file.path("D:/ff-dev/predictionsZillah/LAQ",country))) {dir.create(file.path("D:/ff-dev/predictionsZillah/LAQ",country))}
    writeRaster(LAQ, paste0("D:/ff-dev/predictionsZillah/LAQ/", country,'/', country ,'_', date, "_LAQ.tif"), overwrite=T )

    # get groundtruth per country
    tiles = gfw_tiles[countries[countries$iso3 == country],]$tile_id
    raslist <- list()
    for (tile in tiles) {
      gt_tile = rast(paste0("D:/ff-dev/results/preprocessed/groundtruth/", tile,"/", tile,"_", date,"_groundtruth6m.tif"))
      raslist[[tile]] <- gt_tile
    }
    if (length(raslist) == 1) {groundtruth <- raslist[[1]]}else{
      groundtruth <- do.call(terra::merge,unname(raslist))
    }
    shape <- countries[which(countries$iso3 == country),]
    groundtruth <- terra::mask(groundtruth,shape)
    groundtruth <- terra::crop(groundtruth,shape)
    if (!dir.exists(file.path("D:/ff-dev/results/experimentation/groundtruthCountry", country))) {dir.create(file.path("D:/ff-dev/results/experimentation/groundtruthCountry", country))}
    writeRaster(groundtruth, paste0("D:/ff-dev/results/experimentation/groundtruthCountry/", country,'/', country ,'_', date, "_groundtruth.tif"), overwrite=T )

    cor_amounts = cor(values(amounts),values(groundtruth),use = "complete.obs")[1]
    cor_confidence = cor(values(confidence),values(groundtruth),use = "complete.obs")[1]
    cor_LAQ = cor(values(LAQ),values(groundtruth),use = "complete.obs")[1]



    write.csv(data.frame(country = country, date = date, cor_amounts = cor_amounts, cor_confidence = cor_confidence, cor_LAQ = cor_LAQ),
              file = "D:/ff-dev/predictionsZillah/correlation_groundtruth.csv" )


    F05_confidence = getFscore(values(as.numeric((groundtruth > 0))) , values(confidence, 0.5))
    # Initialize vectors to store F05_amounts and F05_LAQ values
    F05_amounts <- numeric(9)
    F05_LAQ <- numeric(9)

    # Compute F05_amounts and F05_LAQ for i in range(1, 10)
    for (i in 1:9) {
      F05_amounts[i] = getFscore(values(as.numeric((groundtruth > 0))), values(amounts), i)
      F05_LAQ[i] = getFscore(values(as.numeric((groundtruth > 0))), values(LAQ), i)
    }

    # Combine the results into a data frame
    results <- data.frame(
      F05_confidence = F05_confidence,
      t(F05_amounts),
      t(F05_LAQ)
    )

    # Rename the columns
    colnames(results) <- c("F05_confidence",
                           paste0("F05_amounts_", 1:9),
                           paste0("F05_LAQ_", 1:9))

    # Find the highest F0.5 score and its corresponding method
    all_scores <- c(F05_confidence, F05_amounts, F05_LAQ)
    methods <- c("F05_confidence", paste0("F05_amounts_", 1:9), paste0("F05_LAQ_", 1:9))
    max_index <- which.max(all_scores)
    highest_F05_method <- methods[max_index]

    # Add the highest method name as a new column in the results data frame
    results$Highest_F05_Method <- highest_F05_method
    results$country=country
    results$date=date

    # Write the results to a CSV file
    write.csv(results, file = "D:/ff-dev/predictionsZillah/confidence_amounts_LAQ.csv", row.names = FALSE)

    cat("For", country, date, ", correlation amounts:", round(cor_amounts,2),
        "confidence:", round(cor_confidence,2),
        "LAQ:", round(cor_LAQ,2),
        ", best F05 method:", highest_F05_method,"\n")
    # par(mfrow = c(2, 2))
    # plot(amounts, main = "amounts", breaks = c(0,1,5,10,Inf), col=c("lightgray", "orange","red","darkred") )
    # plot(confidence, main = "confidence" )
    # plot(LAQ, main = "LAQ", breaks = c(0,1,5,10,Inf), col=c("lightgray", "orange","red","darkred") )
    # plot(groundtruth, main = "groundtruth", breaks=c(0,1,5,10,Inf), col=c("lightgray", "orange","red","darkred") )
    #

}}
