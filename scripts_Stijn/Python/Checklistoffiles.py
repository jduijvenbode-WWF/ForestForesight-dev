import os

def extract_lat_lon_code(filename):
    # Assuming the codes are at the start of the filename and look like '00N_000E'
    return filename.split('_')[0] + '_' + filename.split('_')[1]

# Directories
dir1 = r"D:\ff-dev\results\preprocessed\input"
dir2 = r"D:\temp\NewDatasetsStijn\Forest edge\ForestEdgeDensity3"

# Gather filenames from both directories
files_dir1 = os.listdir(dir1)
files_dir2 = os.listdir(dir2)

# Extract latitude/longitude codes
codes_dir1 = {extract_lat_lon_code(file) for file in files_dir1 if '_' in file}
codes_dir2 = {extract_lat_lon_code(file) for file in files_dir2 if '_' in file}

# Determine unique codes in each directory
unique_dir1 = codes_dir1 - codes_dir2
unique_dir2 = codes_dir2 - codes_dir1

print("Unique to directory 1:", unique_dir1)
print("Unique to directory 2:", unique_dir2)

