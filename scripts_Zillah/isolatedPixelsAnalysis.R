

data(gfw_tiles,envir = environment())
tiles=gfw_tiles$tile_id

date="2023-01-01"
total_FP_isolated=0
total_TP_isolated=0
total_FP=0
total_TP=0
total_FN=0
beta <- 0.5
th_isolated <- 55
for (tile in tiles){
  tile_pred_values= rast(paste0("D:/ff-dev/results/predictions/", tile, "/", tile, "_", date,"_predictions.tif"))
  tile_pred = tile_pred_values>50
  # Apply the function using focal
  isolated_sel <- focal(tile_pred, w=matrix(c(1,1,1,1,10,1,1,1,1), nrow=3), na.rm=TRUE)==10
  isolated_raster = isolated_sel& tile_pred_values<th_isolated
  tile_gt = rast(paste0("D:/ff-dev/results/preprocessed/groundtruth/", tile, "/", tile, "_", date,"_groundtruth6m.tif"), win=ext(tile_pred))>0
  TP_isolated = sum(values( tile_gt & isolated_raster))
  FP_isolated = sum(values( !tile_gt & isolated_raster))
  total_FP_isolated = total_FP_isolated +FP_isolated
  total_TP_isolated = total_TP_isolated + TP_isolated
  tot_FP = sum(values(tile_pred & !tile_gt))
  tot_TP = sum(values(tile_pred & tile_gt))
  tot_FN = sum(values(!tile_pred & tile_gt))
  total_FP= total_FP+tot_FP
  total_TP = total_TP+tot_TP
  total_FN = total_FN + tot_FN
  print(paste( tile, ":", round((FP_isolated)/(FP_isolated+TP_isolated)*100,2), "% of isolated pixels is FP",
               "this is",round((FP_isolated)/tot_FP*100,2), "% of the total FP" ))
  precision1 = tot_TP/(tot_TP+tot_FP)
  precision2 = (tot_TP-TP_isolated)/((tot_TP-TP_isolated)+(tot_FP-FP_isolated))
  recall1 = tot_TP /(tot_TP +tot_FN)
  recall2 = (tot_TP-TP_isolated)/(tot_TP+tot_FN)
  f05_1 <- (1 + beta^2) * (precision1 * recall1) / (beta^2 * precision1 + recall1)
  f05_2 <- (1 + beta^2) * (precision2 * recall2) / (beta^2 * precision2 + recall2)
  print(paste("Tile ", tile, ": precision 1: ", round(precision1,3)*100, "%, recall 1:", round(recall1,3)*100, "%, F05 1 :", round(f05_1,3)*100, "%"))
  print(paste("Tile ", tile, ": precision increase: ", round((precision2 -precision1)*100,3), "%, recall decrease:", round((recall2 -recall1)*100,3), "%, F05 Increase: ", round((f05_2 -f05_1)*100,3), "%"))
  }

precisiontot1=  total_TP/(total_TP+total_FP)
precisiontot2 = (total_TP-total_TP_isolated)/((total_TP-total_TP_isolated)+(total_FP-total_FP_isolated))

recalltot1=(total_TP/(total_TP+total_FN))
recalltot2=((total_TP-total_TP_isolated)/(total_TP+total_FN))

F05tot1=  (1 + beta^2) * (precisiontot1 * recalltot1) / (beta^2 * precisiontot1 + recalltot1)
F05tot2=  (1 + beta^2) * (precisiontot2 * recalltot2) / (beta^2 * precisiontot2 + recalltot2)

print(paste("For all tiles:", round((total_FP_isolated)/(total_FP_isolated+total_TP_isolated)*100,2), "% of isolated pixels is FP",
             "this is",round((total_FP_isolated)/total_FP*100,2), "% of the total FP" ))

cat(paste0("precision before: ", round(precisiontot1*100,2), "%, precision after removal:", round(precisiontot2*100 ,2), "% increase = ", round((precisiontot2 -precisiontot1)*100,2), "% \n",
           "Recall before: ", round(recalltot1*100,2), "%, recall after removal:", round(recalltot2*100 ,2), "% increase = ", round((recalltot2 -recalltot1)*100,2), "% \n",
           "F0.5-score before: ", round(F05tot1*100,2), "%, after removal:", round(F05tot2*100 ,2), "% increase = ", round((F05tot2 -F05tot1)*100,2), "%"))
