setwd("D:/ff-dev/results/preprocessed")
#setwd("C:/data/storage/preprocessed")
outputfile = "../accuracy_analysis/baseline_TC30.csv"
library(ForestForesight)
files=list.files(recursive=T,pattern="groundtruth6m")

data("degree_polygons")
pols=vect(degree_polygons)
tilesvect <- terra::vect(gfw_tiles)
countries <- vect(countries)
groups = unique(countries$group)
shape <- countries[which(countries$group %in% groups[1:8])]
tiles= tilesvect[shape]$tile_id

calculate_scores=function(predfile,groundtruthfile,pols,adddate=T,fmaskfile=NULL){
  pred=rast(predfile)
  pred[is.na(pred)]=0
  pred=pred>0
  groundtruth=rast(groundtruthfile,win=ext(pred))
  groundtruth[is.na(groundtruth)]=0
  groundtruth=groundtruth>0
  date=substr(basename(groundtruthfile),10,19)
  tile=basename(dirname(predfile))
  if(!is.null(fmaskfile)){
    cat("using forest mask")
    fmask=rast(fmaskfile)
    fmask[is.na(fmask)]=0
    fmask=fmask>0
    cross=(2*groundtruth+pred)*fmask
  }else{cross=2*groundtruth+pred}
  pols$FP=extract(cross==1,pols,fun="sum",na.rm=T,touches=F)[,2]
  pols$FN=extract(cross==2,pols,fun="sum",na.rm=T,touches=F)[,2]
  pols$TP=extract(cross==3,pols,fun="sum",na.rm=T,touches=F)[,2]
  pols$TN=0
  pols$date=date
  pols$tile=tile
  pols=pols[-which(rowSums(as.data.frame(pols)[,c("FP","FN","TP")],na.rm=T)==0),]
  return(pols)
}

# Create a regular expression that matches any of the tile names
tile_pattern <- paste(tiles, collapse = "|")

# Use grep to select files containing any of the tile names
files <- grep(tile_pattern, files, value = TRUE)

files=c(files[grep("2023|2024",files)])
#files=files[-c(grep("2023-01",files),grep("2023-12",files))]
for(x in seq(length(files))){
  file=files[x]
  year <- regmatches(file, regexpr("202[1-4]", file))
  cat(paste0(file," (",x," out of ",length(files),")\n"))
  blfile=gsub("groundtruth","input",gsub("groundtruth6m","lastsixmonths",file))
  fmaskfile=file.path("input",basename(dirname(file)),paste0(basename(dirname(file)),"_", year,"-01-01_initialforestcount30p.tif"))

  groundtruthfile=gsub("predictions","groundtruth",file)
  calcpols=calculate_scores(predfile = blfile,groundtruthfile = groundtruthfile,pols = pols,fmaskfile = fmaskfile)
  if(x==1){allpols=calcpols}else{allpols=rbind(allpols,calcpols)}

}
ap=as.data.frame(allpols)
#op=read.csv(outputfile)
write.csv(ap,outputfile)
# calculate precision, recall, F1 and F0.5. These are not used in powerbi because the score also depends on the size of the polygon
# so the scores below should be calculated on the highest order of scale you are presenting in the data
# example: a polygon of 10x10 meters should not have the same impact on total F05 as a polygon of 10000x10000 meters with many more FN, FP, TP and TN
