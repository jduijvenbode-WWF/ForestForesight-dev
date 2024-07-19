import os
import numpy as np
import rasterio
from scipy.ndimage import uniform_filter

# Function to apply average smoothing
def average_smoothing(data, size):
    # Apply uniform filtering with the specified kernel size
    return uniform_filter(data, size=size)

# Main function to read, process, and save the raster file
def main(input_file, output_file):
    try:
        with rasterio.open(input_file) as src:
            data = src.read(1)  # Read data from Band 1
            profile = src.profile  # Get the geospatial metadata

            # Handle nodata values
            nodata_value = src.nodata
            if nodata_value is not None:
                data[data == nodata_value] = 0
            else:
                data = np.nan_to_num(data)

            # Replace all -1 values with 0
            data[data == -1] = 0

            # Multiply all pixel values by 100 to scale them
            data *= 100

            # Apply average smoothing
            smoothed_data = average_smoothing(data, size=21)

            # Update the profile for saving the output raster
            profile.update(dtype=rasterio.float32, count=1)

            # Write the smoothed data to a new GeoTIFF
            with rasterio.open(output_file, 'w', **profile) as dst:
                dst.write(smoothed_data, 1)

            print(f"Smoothing operation completed successfully for {os.path.basename(output_file)}.")

    except Exception as e:
        print(f"An error occurred: {e}")

# Example usage with paths
if __name__ == "__main__":
    input_file = "D:/temp/NewDatasetsStijn/CropGrids/RiceCropLand2020_resampled.tif"
    output_file = "D:/temp/NewDatasetsStijn/CropGrids/RiceCropLand2020_DistanceTo.tif"
    main(input_file, output_file)
