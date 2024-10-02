spras=rast("C:/data/git/ForestForesight-dev/scripts_jonas/superpixel/10N_080W_202402_classified.tif")
gtras=rast("C:/data/storage/preprocessed/groundtruth/10N_080W/10N_080W_2024-02-01_groundtruth6m.tif")
gtras=1.0*gtras>0

vals=as.numeric(global(spras,fun=quantile,probs=seq(0,1,0.01)))
vals=unique(vals)
spras=as.matrix(spras)
gtras=as.matrix(gtras)
vals=rev(sort(unique(round(unique(spras),3))))
for(val in vals){
  scores=ForestForesight::getFscore(gt = gtras,pred = spras,threshold = val,pr=T)
  cat("val:",val,"F0.5:",round(scores$F05,3),"precision:",round(scores$precision,3),"recall:",round(scores$recall,3),"\n")
}
