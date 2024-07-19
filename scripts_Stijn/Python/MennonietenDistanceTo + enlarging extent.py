import rasterio
import numpy as np
from scipy.ndimage import distance_transform_edt

def enlarge_geotiff(input_geotiff, output_geotiff, additional_kilometers):
    with rasterio.open(input_geotiff) as src:
        input_array = src.read(1)
        metadata = src.profile

        # Calculate how many columns to add
        km_to_degrees = additional_kilometers / 111  # Convert km to degrees, assuming 111km per degree of longitude
        extra_columns = int(km_to_degrees / abs(src.transform[0]))  # Calculate the number of extra columns based on pixel size

        # Pad the array on the right
        padded_array = np.pad(input_array, ((0, 0), (0, extra_columns)), mode='constant', constant_values=0)

        # Update metadata for the output GeoTIFF
        metadata.update(width=src.width + extra_columns)
        
        # Adjust the transform to account for the new width
        new_transform = list(src.transform)
        new_transform[2] = src.transform[2]  # Keep the top left x-coordinate the same
        metadata['transform'] = rasterio.Affine(*new_transform)

        # Write the enlarged array to a new GeoTIFF file
        with rasterio.open(output_geotiff, 'w', **metadata) as dst:
            dst.write(padded_array, 1)

def distance_to_nearest_nonzero_geotiff(input_geotiff, output_geotiff):
    with rasterio.open(input_geotiff) as src:
        input_array = src.read(1)
        metadata = src.profile

        # Handle no-data values
        if src.nodata is not None:
            input_array[input_array == src.nodata] = 0
        input_array[np.isnan(input_array)] = 0

        mask = input_array != 0  # Create a binary mask where non-zeros are foreground

        # Calculate Euclidean distance transform
        distance_transform = distance_transform_edt(~mask)  # Invert mask for distance calculation
        # Normalize and scale distances
        distance_transform = np.round(255 - 20 * np.log(distance_transform + 1))
        distance_transform = np.clip(distance_transform, 0, 255)  # Clamp values to a range of 0 to 255

        # Write the distance transform array to a new GeoTIFF file
        metadata.update(dtype='float32')
        with rasterio.open(output_geotiff, 'w', **metadata) as dst:
            dst.write(distance_transform.astype(rasterio.float32), 1)

# Paths for the functions
input_geotiff_path = "D:/temp/NewDatasetsStijn/Mennonieten/ColoniesMennonites2020_Smoothed.tif"
enlarged_geotiff_path = "D:/temp/NewDatasetsStijn/Mennonieten/ColoniesMennonites2020_Enlarged4.tif"
output_distance_geotiff_path = "D:/temp/NewDatasetsStijn/Mennonieten/ColoniesMennonites2020_DistanceTo6.tif"

# Enlarge the geotiff by an additional 2.5 kilometers
enlarge_geotiff(input_geotiff_path, enlarged_geotiff_path, 750)

# Calculate the distance to the nearest nonzero after enlargement
distance_to_nearest_nonzero_geotiff(enlarged_geotiff_path, output_distance_geotiff_path)

