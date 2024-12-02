cat("starting preprocessing\n")
# Load the argparse package
library(argparse)

# Create argument parser
parser <- ArgumentParser(description = "Script for processing data with specified options")

# Add arguments
parser$add_argument("-d", "--max-date",
                    dest = "max_date",
                    default = format(Sys.Date(), "%Y-%m-01"),
                    help = "Maximum date (default: first of the current month)")

parser$add_argument("-c", "--cores",
                    dest = "cores",
                    default = "9",
                    help = "Number of cores (default: 9)")

parser$add_argument("-s", "--script-location",
                    dest = "script_location",
                    required = FALSE,
                    default= "C:/Users/EagleView/Documents/GitHub/ForestForesight-dev/preprocessing/IA-processing_monthly.py",
                    help = "Location of the processing script (must be a Python script)")
parser$add_argument("-i", "--input_folder",
                    dest = "input_folder",
                    required = FALSE,
                    default= "D:/ff-dev/alerts/",
                    help = "Location of the input folder that contains the GFW integrated alert tif files")
parser$add_argument("-p", "--prep_folder",
                    dest = "prep_folder",
                    required = FALSE,
                    default= "D:/ff-dev/results/preprocessed/",
                    help = "Location of the preprocessed data folder")
parser$add_argument("-dr", "--dryrun",
                    dest = "dryrun",
                    required = FALSE,
                    default= "0",
                    help = "checks only if files need to be processed")
# Parse arguments
args <- parser$parse_args()
if(!dir.exists(args$input_folder)){stop("input folder does not exist")}
if(!dir.exists(args$prep_folder)){stop("preprocessed data folder does not exist")}
# Check if the script location ends with ".py"
if (!grepl("\\.py$", args$script_location)) {
  stop("Error: The script location must be a Python script (*.py)")
}
if(!file.exists(args$script_location)){stop("the given python script does not exist")}
# Print parsed arguments
cat("Maximum date:", args$max_date, "\n")
max_date=args$max_date
cat("Number of cores:", args$cores, "\n")
cat("Script location:", args$script_location, "\n")
cores=as.numeric(args$cores)
if(is.na(cores)){stop("core count was not a number")}

library(ForestForesight)
library(parallel)

#max_date="2024-05-01"


layers=c("layer")
comb1=apply(expand.grid(max_date, layers), 1, paste, collapse="_")

data("gfw_tiles")
tiles=vect(gfw_tiles)$tile_id
comb2=paste0(tiles,"_",max_date,"_layer.tif")
allfiles=paste0(file.path(args$prep_folder,"input",substr(comb2,1,8),comb2))




commandtxts=paste("python",
                  args$script_location,
                  paste0(args$input_folder,basename(dirname(allfiles)),".tif"),
                  allfiles,
                  as.numeric(as.Date(substr(basename(allfiles),10,19))-as.Date("2015-01-01")),
                  "--groundtruth1m 1",
                  "--groundtruth3m 1",
                  "--groundtruth6m 1",
                  "--groundtruth12m 1")

cat(paste("processing",length(commandtxts),"files\n"))
if(args$dryrun=="1"){stop()}


cl <- makeCluster(getOption("cl.cores", cores))
clusterExport(cl, "commandtxts")
results <- clusterApply(cl, commandtxts, system)

# Stop the cluster
stopCluster(cl)

