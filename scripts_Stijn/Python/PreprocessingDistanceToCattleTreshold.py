import rasterio
import numpy as np
from scipy.ndimage import distance_transform_edt

def distance_to_nearest_nonzero_geotiff(input_geotiff, output_geotiff):
    # Read the GeoTIFF file
    with rasterio.open(input_geotiff) as src:
        # Read the data
        input_array = src.read(1)
        # Get the metadata for creating the output GeoTIFF
        metadata = src.profile

    # Create a binary mask where zeros are treated as foreground and non-zeros as background
    input_array[np.isnan(input_array)] = 0
    mask = input_array < 10000
    print(np.max(mask))
    print(np.max(input_array))

    # Calculate Euclidean distance transform
    distance_transform = distance_transform_edt(mask)
    distance_transform = np.round(255 - 20 * np.log(distance_transform + 1))
    # Update metadata for the output GeoTIFF
    metadata.update(dtype='float32', count=1)
    distance_transform[distance_transform > 255] = 255
    distance_transform[distance_transform < 0] = 0
    distance_transform[np.isnan(distance_transform)] = 0
    # Write the distance transform array to a new GeoTIFF file
    with rasterio.open(output_geotiff, 'w', **metadata) as dst:
        dst.write(distance_transform.astype(rasterio.float32), 1)

# Direct path to your input and output GeoTIFF
input_geotiff_path = "D:/temp/ForestmaskJonasscript/Cattle distribution/Cattle Distribution DA.tif"
output_geotiff_path = "D:/temp/ForestmaskJonasscript/Cattle distribution/Cattle Distribution DA_DistanceTo.tif"

# Call the function with the specified paths
distance_to_nearest_nonzero_geotiff(input_geotiff_path, output_geotiff_path)
