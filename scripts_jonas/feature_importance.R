library(ForestForesight)
setwd("C:/data/storage/models")
xgbmodels=list.files(recursive = T,full.names = T,pattern="model$")
first=T
for(xgbmodel in xgbmodels){
  nextv=F
  a=xgb.load(xgbmodel)
  modelname=gsub(".model","",basename(xgbmodel))
  featuredataset=gsub(".model",".rda",xgbmodel)
  features=get(load(featuredataset))
  tryCatch({importance_matrix=xgb.importance(feature_names=features,model=a)}, error = function(e) {
    # Print the error message
    print(paste("An error occurred:", e))
    print(modelname)
    nextv=T
    # Continue the loop or execute other code as needed
  })
  if(!nextv){
    importance_matrix=as.data.frame(importance_matrix)
    metdat=ForestForesight::get_feature_metadata()

    metdat2=cbind(metdat[,2:4],sapply(metdat[,5],function(x) sub(".*\\[(.*?)\\].*", "\\1", x)))
    metdat2=metdat2[-1,]
    finaldat=merge(metdat2,importance_matrix,by.x="feature",by.y="Feature")
    names(finaldat)=c("feature_short","feature_name","periodicity","source","gain","cover","frequency")
    finaldat$model=modelname
    if(first){first=F;alldat=finaldat}else{alldat=rbind(alldat,finaldat)}
  }
}
write.csv(alldat,"../../allimportance.csv")
