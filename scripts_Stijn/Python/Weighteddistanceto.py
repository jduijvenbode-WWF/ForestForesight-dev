import rasterio
import numpy as np
from scipy.ndimage import gaussian_filter, distance_transform_edt

def create_weighted_distance_map(value_raster_path, output_raster_path, sigma=2):
    with rasterio.open(value_raster_path) as src:
        data = src.read(1)  # Read the first band
        profile = src.profile
        
        # Temporarily convert data to float for processing if it's not already float
        data_float = data.astype('float32')
        
        # Handle nodata values and normalize the data
        nodata = profile.get('nodata', None)
        if nodata is not None:
            data_float[data == nodata] = np.nan

        # Normalize the data
        min_val = np.nanmin(data_float)
        max_val = np.nanmax(data_float)
        normalized_data = (data_float - min_val) / (max_val - min_val) if max_val > min_val else data_float

        # Apply Gaussian smoothing
        smoothed_data = gaussian_filter(normalized_data, sigma=sigma, mode='nearest')

        # Invert the data for distance calculation: higher values get lower "distance costs"
        smoothed_data = np.clip(smoothed_data, 0.01, 1)  # Ensure data is not too close to zero
        inverted_data = 1 / smoothed_data

        # Calculate the weighted distance transform
        distance = distance_transform_edt(inverted_data)

        # Normalize the distance map for visualization
        distance_normalized = (distance - np.nanmin(distance)) / (np.nanmax(distance) - np.nanmin(distance))
        distance_scaled = distance_normalized * 255
        
        # Update the profile for output
        profile.update(dtype='float32', nodata=None, compress='lzw')

        # Save the distance map
        with rasterio.open(output_raster_path, 'w', **profile) as dst:
            dst.write(distance_scaled.astype('float32'), 1)

# Define paths
input_value_raster = "D:/temp/NewDatasetsStijn/Soy/Soy 2024.tif"
output_distance_raster = "D:/temp/NewDatasetsStijn/Soy/Soy 2024_weighteddistanceto.tif"

# Generate the weighted distance map
create_weighted_distance_map(input_value_raster, output_distance_raster)
