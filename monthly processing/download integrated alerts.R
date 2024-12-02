library(ForestForesight)
data("gfw_tiles")
IA=vect(gfw_tiles)
setwd("D:/ff-dev/alerts/")
apikey="8892b7c2-7350-46ef-9b0e-5f3aacf92c0e"
for(id in seq(nrow(IA))){
  file=IA$download[id]
  file=paste0(substr(file,1,gregexpr("key=",file)[[1]][1]+3),apikey)
  name=IA$tile_id[id]
  b=httr::GET(file)
  writeBin(b$content,paste0(name,".tif"))
  cat(paste(Sys.time(),name,"\n"))
}
