setwd("D:/ff-dev/results/preprocessed")
outputfile="../accuracy_analysis/baseline_amounts_alldata.csv"
library(ForestForesight)
files=list.files(recursive=T,pattern="groundtruth6m")

data("degree_polygons")
pols=vect(degree_polygons)
pols=vect(degree_polygons)
calculate_scores=function(predfile,groundtruthfile,pols,adddate=T,fmaskfile=NULL){
  pred=rast(predfile)
  pred[is.na(pred)]=0
  groundtruth=rast(groundtruthfile,win=ext(pred))
  groundtruth[is.na(groundtruth)]=0
  date=substr(basename(groundtruthfile),10,19)
  tile=basename(dirname(predfile))
  if(!is.null(fmaskfile)){
    cat("using forest mask")
    fmask=rast(fmaskfile)
    fmask[is.na(fmask)]=0
    fmask=fmask>0
    se = ((groundtruth - pred)^2)*fmask
  }else{se = (groundtruth - pred)^2}
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
  fmaskfile=file.path("input",basename(dirname(file)),paste0(basename(dirname(file)),"_2021-01-01_initialforestcover.tif"))

  groundtruthfile=gsub("predictions","groundtruth",file)
  calcpols=calculate_scores(predfile = blfile,groundtruthfile = groundtruthfile,pols = pols,fmaskfile = fmaskfile)
  if(x==1){allpols=calcpols}else{allpols=rbind(allpols,calcpols)}

}
ap=as.data.frame(allpols)

write.csv(ap,outputfile)
