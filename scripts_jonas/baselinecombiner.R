setwd("D:/ff-dev/results/accuracy_analysis/")
blfiles=list.files(pattern="baseline_")
blfiles=blfiles[nchar(blfiles) %in% c(15,16)]
rm(allval)
for(blfile in blfiles){
  a=read.csv(blfile)
  thresh=as.numeric(substr(blfile,10,12))
  TP=sum(a$TP)
  FP=sum(a$FP)
  FN=sum(a$FN)
  precision=TP/(TP+FP)
  recall=TP/(TP+FN)
  F05=1.25*precision*recall/(0.25*precision+recall)
  if(!exists("allval")){allval=c(precision,recall,F05,thresh)}else{allval=rbind(allval,c(precision,recall,F05,thresh))}
}
allval=as.data.frame(allval)
names(allval)=c("precision","recall","F05","threshold")
allval$threshold = as.numeric(allval$threshold)
allval[order(allval$threshold),]
library(ggplot2)
ggplot(allval,aes(x="threshold",y="F05"))+geom_line()
