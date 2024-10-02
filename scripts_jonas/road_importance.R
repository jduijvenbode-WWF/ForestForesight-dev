shape=vect(get(data(countries)))
shape=shape[shape$iso3=="BGD"]

ff_run(shape=shape,train_start="2023-12-01",train_end="2023-12-01",save_path="C:/data/storage/experimentation/EOY_roads.model",ff_folder="C:/data/storage")
dates=daterange("2021-01-01","2023-12-01")
importances=c()
relimportances=c()
impdf=data.frame()
for(date in dates){
  cat(date)
  ff_run(shape=shape,train_start=date,train_end=date,save_path="C:/data/storage/experimentation/imp_roads.model",ff_folder="C:/data/storage")
  imp=ff_importance("C:/data/storage/experimentation/imp_roads.model",output_csv = "C:/data/imp.csv")
  index=grep("closenesstoroads",imp$feature)
  if(length(index)==0){impdf=rbind(impdf,data.frame("date"=date,importance=0,rank=nrow(imp)+1))}else{
    impdf=rbind(impdf,data.frame("date"=date,importance=imp$importance[index],rank=imp$rank[index]))
  }
}
impdf2=data.frame(month=seq(12),rank=(impdf$rank[1:12]+impdf$rank[13:24]+impdf$rank[25:36]/3))
impdf2$rank=max(impdf2$rank)-impdf2$rank
plot(impdf2$rank)
lines(impdf2$rank)

