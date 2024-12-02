mlflow_set_tracking_uri("http://ec2-3-255-204-156.eu-west-1.compute.amazonaws.com:5000/")
regions = unique(get(data("countries"))$group)
results=read.csv("D:/ff-dev/results/accuracy_analysis/baseline_190.csv")
testrange = daterange("2023-01-01","2023-12-01")
for(region in regions){
  countries=get(data("countries"))
  country_ids=countries$iso3[countries$group==region]
  curresults = results[results$iso3 %in% country_ids,]
  curresults = curresults[curresults$date %in% testrange,]

  params_list <- list(
    backwards_days = 190,
    forestmask = "initialforestcover",
    threshold = ">0"
  )
  TP=sum(curresults$TP)
  FP = sum(curresults$FP)
  FN = sum(curresults$FN)
  TN = sum(curresults$TN)
  precision=TP/(TP+FP)
  recall = TP/(TP+FN)
  F05 = 1.25*precision*recall/(0.25*precision+recall)
  if(hasvalue(F05)){

    metrics_list <- list(
      "F0.5" = F05,
      precision = precision,
      recall = recall,
      TP = TP,
      FP = FP,
      FN = FN,
      TN = TN
    )
    result <- ff_log_model(
      region_name = region,
      method_iteration = "190 days",
      algorithm = "baseline",
      params_list = params_list,
      metrics_list = metrics_list,
      flavor = "baseline",verbose = T
    )
    ff_cat(region,F05)
  }else{
    ff_cat(region,color="red")
  }
}
