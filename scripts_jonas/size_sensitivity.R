library(ForestForesight)
setwd("D:/ff-dev/results/preprocessed/input/")
tile="10N_080W"
tiles=vect(get(data("gfw_tiles")))
center=centroids(tiles[which(tiles$tile_id==tile),])
pixsize=res(rast(list.files(path=tile,full.names = T)))[1]
pixsize=pixsize*110000
scales=c(1e5,1e6,1e7,1e8,1e9,1e10)*440
radius=sqrt(scales/pi)
buffsize=sqrt(scales*pixsize/pi)
for(i in seq_along(radius)){
  pol=buffer(center,radius[i])
  if(i==1){allpols=pol}else{allpols=rbind(allpols,pol)}
}
# for(i in seq(length(allpols))){
#   ff_run(shape=allpols[i,],train_start = "2023-01-01",train_end="2023-06-01",ff_folder="D:/ff-dev/results/",
#          save_path = paste0("D:/ff-dev/results/experimentation/size_sensitivity/size_",i,".model"),autoscale_sample = T, validation = T)
# }
for(j in seq(length(allpols))){
  for(i in seq(6)){
    result=ff_run(shape=allpols[j,],prediction_dates = daterange("2024-01-01","2024-02-01"),ff_folder="D:/ff-dev/results/",
           trained_model = paste0("D:/ff-dev/results/experimentation/size_sensitivity/size_",i,".model"),accuracy_csv = paste0("D:/ff-dev/results/experimentation/size_sensitivity/train_",j,"_test_",i,".csv"),autoscale_sample = T, validation = T)
  }
}
res=matrix(nrow=6,ncol=6)
for(j in seq(6)){
  for(i in seq(6)){
    cat(i,j)
    sinres=read.csv(paste0("D:/ff-dev/results/experimentation/size_sensitivity/train_",j,"_test_",i,".csv"))
    precision=sum(sinres$TP,na.rm=T)/(sum(sinres$TP,na.rm=T)+sum(sinres$FP,na.rm=T))
    recall=sum(sinres$TP,na.rm=T)/(sum(sinres$TP,na.rm=T)+sum(sinres$FN,na.rm=T))
    F05=1.25*precision*recall/(0.25*precision+recall)
    res[i,j]=F05
  }
}

