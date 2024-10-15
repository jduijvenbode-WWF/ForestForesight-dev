library(ForestForesight)
dates=daterange("2023-10-01","2024-03-01")
countries=vect(get(data(countries)))[c(1,2,4,5,6,10)]
setwd("C:/data/storage")
results=data.frame()
for(x in 1:nrow(countries)){
  country=countries[x,]
  print(country$iso3)
  for(date in dates){
    print(date)
    colras=rast(paste0("predictions/",country$iso3,"/",country$iso3,"_",date,".tif"))
    colras[colras<0.5]=NA
    high_threshold <- as.numeric(terra::global(colras, fun = quantile, probs = 0.70, na.rm = TRUE))
    highest_threshold <- as.numeric(terra::global(colras, fun = quantile, probs = 0.90, na.rm = TRUE))
    info=getinfo(country,verbose=F)

    medium_risk <- ff_polygonize(colras, threshold = 0.5)
    high_risk <- ff_polygonize(colras, threshold = high_threshold)
    highest_risk <- ff_polygonize(colras, threshold = highest_threshold)

    for(per in c(1,3,6,-6)){
      if(per>0){
        mosaicras=do.call(terra::merge,unname(sapply(info$tile_ids,function(x) rast(paste0("preprocessed/groundtruth/",x,"/",x,"_",date,"_groundtruth",per,"m.tif")))))
      }else{
        mosaicras=do.call(terra::merge,unname(sapply(info$tile_ids,function(x) rast(paste0("preprocessed/input/",x,"/",x,"_",date,"_lastsixmonths.tif")))))
      }
      mosaicras=mosaicras>0
      medvals=terra::extract(mosaicras,medium_risk,fun="mean")
      highvals=terra::extract(mosaicras,high_risk,fun="mean")
      veryhighvals=terra::extract(mosaicras,highest_risk,fun="mean")
      results=rbind(results,c(country$iso3,date,per,"medium",mean(medvals[,2]>0),mean(medvals[,2],na.rm=T)))
      results=rbind(results,c(country$iso3,date,per,"high",mean(highvals[,2]>0),mean(highvals[,2],na.rm=T)))
      results=rbind(results,c(country$iso3,date,per,"veryhigh",mean(veryhighvals[,2]>0),mean(veryhighvals[,2],na.rm=T)))
    }
    results=rbind(results,res)
  }
}
names(results)=c("country","date","period","zone","chance_area","chance_randomloc")
write.csv(results,"experimentation/analysis_newhotzones2.csv")
