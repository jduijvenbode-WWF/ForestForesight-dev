import rasterio
import numpy as np
from scipy.ndimage import distance_transform_edt
import os
import glob

def distance_to_nearest_nonzero_geotiff(input_geotiff, output_geotiff):
    with rasterio.open(input_geotiff) as src:
        input_array = src.read(1)
        metadata = src.profile

        # Handle no-data values, NaNs, and negative values
        if src.nodata is not None:
            input_array[input_array == src.nodata] = 0
        input_array[np.isnan(input_array)] = 0
        input_array[input_array < 0] = 0  # Set negative values to zero

    # Create a binary mask where zeros are treated as background and non-zeros as foreground
    mask = input_array != 0
    # Calculate Euclidean distance transform for non-zero (foreground) elements
    distance_transform = distance_transform_edt(~mask)
    # Normalize the distance transform for better visual interpretation
    distance_transform = np.round(255 - 20 * np.log(distance_transform + 1))
    distance_transform = np.clip(distance_transform, 0, 255)

    # Update metadata for the output GeoTIFF
    metadata.update(dtype='float32', count=1, compress='lzw')
    # Write the distance transform array to a new GeoTIFF file
    with rasterio.open(output_geotiff, 'w', **metadata) as dst:
        dst.write(distance_transform.astype(rasterio.float32), 1)

# Directory containing input GeoTIFF files
input_dir = r"D:\temp\NewDatasetsStijn\CropGrids\CropGridsResampledpertile"
output_dir = r"D:\temp\NewDatasetsStijn\CropGrids\CropGridsResampledDistanceTo"

# Ensure output directory exists
os.makedirs(output_dir, exist_ok=True)

# Process each GeoTIFF file in the input directory
for input_file in glob.glob(os.path.join(input_dir, '*.tif')):
    file_name = os.path.basename(input_file)
    # Replace 'resampled_crs' or 'resampled_crs2' in file names
    modified_name = file_name.replace('resampled_crs', 'DistanceTo').replace('resampled_crs2', 'DistanceTo')
    output_file = os.path.join(output_dir, modified_name)

    # Call the function to process each file
    distance_to_nearest_nonzero_geotiff(input_file, output_file)
    print(f"Processed {file_name} to {modified_name}")
