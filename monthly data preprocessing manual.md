# monthly data preprocessing
at the moment there are three data sources that need to be updated monthly, being the Integrated Alerts, the forest fires and the nighttime activity. Later on this manual will be expanded to include yearly datasets like the hansen loss and distance to roads.

## integrated alerts
### download
to download the integrated alerts run the following lines:

```
#requires the package ForestForesight
library(ForestForesight)
data("gfw_tiles")
IA=vect(gfw_tiles)

setwd(dir.choose()) #for us this is the folder D:/ff-dev/alerts
for(id in seq(nrow(IA))){
  file=IA$download[id]
  name=IA$tile_id[id]
  b=httr::GET(file)
  writeBin(b$content,paste0(name,".tif"))
}
```

### process
after this all the datasets that rely on the integrated alerts can be processed (check readme for an overview). You need a conda environment with at least the following python packages for that
- rasterio
- scipy
- numpy
- argparse

you also need to have R installed and be recognized by your conda environment (test by typing in Rscript in the command line). R requires the following installed packages:
- parallel
- ForestForesight
- argparse


run the following line in the conda environment
~~~
Rscript C:\Users\EagleView\Documents\GitHub\ForestForesight\preprocessing\python_preprocessing_missing_multicore.R
~~~
this will create all the datasets that do not yet exist in the folder D:/ff-dev/results/preprocessed that are based on the integrated alerts. 
- If you want to process this on your own computer make sure to set all the correct flags (prep_folder, input_folder, script_location and cores) 
- You can add the -d flag to only process up to a certain month (between 2021-01-01 and that date, in the format of yyyy-mm-dd)
- Change the path to the Rscript if it is somewhere else


## nighttime activity
### download
you need a token from the LDAAP repository to download it. you also need to have wget installed in your command line. Check the data availability [here](https://ladsweb.modaps.eosdis.nasa.gov/archive/allData/5000/VNP46A3). Then run the following line with a few adaptations:

~~~
wget -e robots=off -m -np -R .html,.tmp -nH --cut-dirs=3 "https://ladsweb.modaps.eosdis.nasa.gov/archive/allData/5000/VNP46A3/2023/335/" --header "Authorization: Bearer eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJlbWFpbF9hZGRyZXNzIjoianZkdWlqdmVuYm9kZUBnbWFpbC5jb20iLCJpc3MiOiJBUFMgT0F1dGgyIEF1dGhlbnRpY2F0b3IiLCJpYXQiOjE3MDY2MDYxNTUsIm5iZiI6MTcwNjYwNjE1NSwiZXhwIjoxODY0Mjg2MTU1LCJ1aWQiOiJmZXJkeXdhbGxpbngiLCJ0b2tlbkNyZWF0b3IiOiJmZXJkeXdhbGxpbngifQ.xi5OZCVGgORmuNxeoRaYynzQWIzLbBG4Sz86SCZboss" -P .
~~~
This will download the data for the last month of 2023. Change the url to download a full year or a specific month. You can change the dot to the directory you want to save it to (for us D:\ff-dev\nighttime\ by using pushd D:\ff-dev\nighttime\ in the command line)

### process
In Rstudio run the script called converting_nightlights_h5_geotiff.R in the folder preprocessing. No changes are required for the processing pc's of Forest Foresight. Other users have to change the path in the script. It does require GDAL to be installed with the folder GDAL_DATA added to the system environment variables

## forest fires
### download
the fire alerts need to be downloaded manually. First go to . Then press new request at the bottom and enter the following fields:
- world should be set to custom region and then the coordinate -180,-30,180,30 (for the pantropical belt)
- choose MODIS and the three LAADS options
- Set the date range according to what you want to process (for us the first of last month until the first of the month that you currently want to process)
- enter the email adress to which the downloadable data will be sent as a link. 

You will get an email when your data is ready.
### process
