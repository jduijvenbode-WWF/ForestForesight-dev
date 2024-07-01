

data(gfw_tiles,envir = environment())
tiles=gfw_tiles$tile_id

date="2022-08-01"
total_isolated=0
total_TP_isolated=0
total_FP=0
for (tile in tiles){
  tile_pred= rast(paste0("D:/ff-dev/results/predictions/", tile, "/", tile, "_", date,"_predictions.tif"))>0.5
  # Apply the function using focal
  isolated_raster <- focal(tile_pred, w=matrix(c(1,1,1,1,10,1,1,1,1), nrow=3), na.rm=TRUE)==10
  tot_isolated = sum(values(isolated_raster))
  tile_gt = rast(paste0("D:/ff-dev/results/preprocessed/groundtruth/", tile, "/", tile, "_", date,"_groundtruth6m.tif"), win=ext(tile_pred))>0
  TP_isolated = sum(values( tile_gt & isolated_raster))
  total_isolated = total_isolated + tot_isolated
  total_TP_isolated = total_TP_isolated + TP_isolated
  tot_FP = sum(values(tile_pred &!tile_gt))
  total_FP= total_FP+tot_FP
  print(paste( tile, ":", round((tot_isolated-TP_isolated)/tot_isolated*100,2), "% of isolated pixels is FP",
               "this is",round((tot_isolated-TP_isolated)/tot_FP*100,2), "% of the total FP" ))

  }

print(paste(" For all tiles:", round((total_isolated -total_TP_isolated )/total_isolated*100,2), "% of isolated pixels is FP",
  "this is",round((total_isolated -total_TP_isolated)/total_FP*100,2), "% of the total FP" ))
