import rasterio
import os
import glob
import numpy as np

def set_nodata_values_to_255(geotiff_path):
    # Open the GeoTIFF file
    with rasterio.open(geotiff_path) as src:
        # Read the data
        data = src.read(1)  # Assumes that the data is in the first band
        # Fetch the metadata from the source file
        metadata = src.profile

        # Fetch the nodata value from the file; proceed if it's defined
        nodata_value = src.nodata
        if nodata_value is not None:
            # Identify where the data is equal to the nodata value
            nodata_mask = (data == nodata_value)
            # Set these locations to 255
            data[nodata_mask] = 255
            # It's important to set the internal nodata value to None or update it to reflect the new encoding
            metadata['nodata'] = None  # Removing the nodata flag entirely since we're converting nodata to valid data

    # Write the modified data back to the same file
    with rasterio.open(geotiff_path, 'w', **metadata) as dst:
        dst.write(data, 1)

# Directory containing the GeoTIFF files
input_dir = r"D:\temp\NewDatasetsStijn\CropGrids\CropGridsResampledDistanceTo"

# Process each GeoTIFF file in the directory
for geotiff_file in glob.glob(os.path.join(input_dir, '*.tif')):
    set_nodata_values_to_255(geotiff_file)
    print(f"Processed {os.path.basename(geotiff_file)}")
