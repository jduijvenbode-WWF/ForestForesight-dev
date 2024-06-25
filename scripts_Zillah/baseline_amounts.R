setwd("D:/ff-dev/results/preprocessed")
outputfile="D:/ff-dev/predictionsZillah/accuracy_analysis/baseline_amounts_binpred.csv"
library(ForestForesight)
files=list.files(recursive=T,pattern="groundtruth6m")

data("degree_polygons")
pols=vect(degree_polygons)
calculate_scores=function(predfile,groundtruthfile,pols,adddate=T,binpredfile, totdeffile){
  pred=rast(predfile)
  pred[is.na(pred)]=0
  max_def = 1600-rast(totdeffile,win=ext(pred))
  bin_pred= rast(binpredfile,win=ext(pred))>50
  groundtruth=rast(groundtruthfile,win=ext(pred))
  groundtruth[is.na(groundtruth)]=0
  date=substr(basename(groundtruthfile),10,19)
  tile=basename(dirname(predfile))
  se = (groundtruth - min(max_def,pred))
  se[!bin_pred]=NA
  pols$rmse <- (terra::extract(se,pols,fun = "mean",na.rm = T,touches = F)[,2])^0.5
  pols$date=date
  pols$tile=tile
  pols=pols[-which(rowSums(as.data.frame(pols)["rmse"],na.rm=T)==0),]
  return(pols)
}
for(x in 1:length(files)){
  file=files[x]
  cat(paste0(file," (",x," out of",length(files),")\n"))
  blfile=gsub("groundtruth","input",gsub("groundtruth6m","lastsixmonths",file))
  totdeffile= gsub("groundtruth","input",gsub("groundtruth6m","totallossalerts",file))
  binpredfile= paste0("D:/ff-dev/results/",gsub("groundtruth","predictions",gsub("groundtruth6m","predictions",file)))
  if (file.exists(binpredfile)){
    calcpols=calculate_scores(predfile = blfile,groundtruthfile = file,pols = pols,binpredfile=binpredfile, todeffile=totdeffile)
    if(!exists("allpols")){allpols=calcpols}else{allpols=rbind(allpols,calcpols)}}
}
ap=as.data.frame(allpols)

write.csv(ap,outputfile)
rm(allpols)
