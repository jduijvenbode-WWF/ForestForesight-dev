library(ForestForesight)
setwd("D:/ff-dev/results/preprocessed/input/")
tiles = vect(get(data("gfw_tiles")))

# Function to create a new extent anchored at upper left
create_ul_extent <- function(original_ext, size_reduction) {
  xmin <- original_ext[1] + 0.01
  ymax <- original_ext[4] + 0.01
  new_xmax <- xmin + (original_ext[2] - original_ext[1]) - size_reduction + 0.01
  new_ymin <- ymax - (original_ext[4] - original_ext[3]) + size_reduction + 0.01
  return(ext(xmin, new_xmax, new_ymin, ymax))
}


for (tile in c("20N_100E", "10S_070W", "00N_010E", "00N_110E", "00N_080W")) {
  tileext= ext(tiles[tiles$tile_id == tile])
  # Create list of extents
  list_ext <- list(
    create_ul_extent(tileext, 0.1*2),
    create_ul_extent(tileext, 2.5*2),
    create_ul_extent(tileext, 4*2),
    create_ul_extent(tileext, 4.5*2)
  )
  names = c( 10-0.1*2,10-2.5*2,10-4*2,10-4.5*2,10-4.75*2)
  allpols= lapply(list_ext, as.polygons)
  #crs(allpols)=crs(tiles)

#
#   for(i in seq(4)){
#     crs(allpols[[i]])=crs(tiles)
#     ff_run(shape=allpols[[i]],train_start = "2023-01-01",train_end="2023-06-01",
#            ff_folder="D:/ff-dev/results/", validation_dates = daterange("2022-04-01", "2022-06-01"),
#            save_path = paste0("D:/ff-dev/results/experimentation/size_sensitivity/size_",tile,i,".model"),autoscale_sample = T)
#   }

  for(j in seq(4)){
    crs(allpols[[j]])=crs(tiles)
    for(i in seq(4)){
      result=ff_run(shape=allpols[[j]],prediction_dates = daterange("2024-01-01","2024-02-01"),ff_folder="D:/ff-dev/results/",
                    trained_model = paste0("D:/ff-dev/results/experimentation/size_sensitivity/size_",tile,i,".model"),
                    accuracy_csv = paste0("D:/ff-dev/results/experimentation/size_sensitivity/", tile,"_train_",i,"_test_",j,".csv"),
                    autoscale_sample = T, validation = T)
    }
  }
  res=matrix(nrow=4,ncol=4)
  for(j in seq(4)){
    for(i in seq(4)){
      sinres=read.csv(paste0("D:/ff-dev/results/experimentation/size_sensitivity/", tile,"_train_",i,"_test_",j,".csv"))
      precision=sum(sinres$TP,na.rm=T)/(sum(sinres$TP,na.rm=T)+sum(sinres$FP,na.rm=T))
      recall=sum(sinres$TP,na.rm=T)/(sum(sinres$TP,na.rm=T)+sum(sinres$FN,na.rm=T))
      F05=1.25*precision*recall/(0.25*precision+recall)
      res[i,j]=F05
    }
  }
  rownames(res)=names[1:4]
  colnames(res)=names[1:4]
  write.csv(res, paste0("D:/ff-dev/results/experimentation/size_sensitivity/F05_tables/", tile, "_F05table.csv" ))

}
