import os
import rasterio
import numpy as np
from scipy.ndimage import distance_transform_edt

def distance_to_nearest_nonzero_geotiff(input_geotiff, output_geotiff):
    with rasterio.open(input_geotiff) as src:
        # Read the data
        input_array = src.read(1)
        # Get the metadata for creating the output GeoTIFF
        metadata = src.profile
        if src.nodata is not None:
            input_array[input_array == src.nodata] = 0
        input_array[np.isnan(input_array)] = 0

    mask = input_array != 0  # Create a binary mask where non-zeros are foreground

    # Calculate Euclidean distance transform
    distance_transform = distance_transform_edt(~mask)  # Invert mask for distance calculation
    # Transform distances to a more visually interpretable scale
    distance_transform = np.round(255 - 20 * np.log(distance_transform + 1))
    # Clamp values to a range of 0 to 255 and handle NaNs
    distance_transform = np.clip(distance_transform, 0, 255)

    # Update metadata for the output GeoTIFF
    metadata.update(dtype='float32', count=1, compress='lzw')

    # Write the distance transform array to a new GeoTIFF file
    with rasterio.open(output_geotiff, 'w', **metadata) as dst:
        dst.write(distance_transform.astype(rasterio.float32), 1)

# Directory setup
src_directory = r"D:\temp\NewDatasetsStijn\Forest edge\EdgeMaps2resampled"
output_directory = r"D:\temp\NewDatasetsStijn\Forest edge\DistanceToForestEdge2"

os.makedirs(output_directory, exist_ok=True)

# Process each file
for filename in os.listdir(src_directory):
    if filename.endswith('.tif'):  # Assuming you want to process all TIFF files in the directory
        src_path = os.path.join(src_directory, filename)
        base_name = os.path.splitext(filename)[0]
        output_path = os.path.join(output_directory, f"{base_name}_distance.tif")
        distance_to_nearest_nonzero_geotiff(src_path, output_path)
        print(f"Processed {src_path} and saved to {output_path}")

