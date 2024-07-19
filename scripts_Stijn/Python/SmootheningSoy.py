import os
import numpy as np
import rasterio
from scipy.ndimage import convolve

# Function to apply weighted smoothing
def weighted_smoothing(data, window_size):
    # Create a weighted distance matrix
    x, y = np.meshgrid(np.arange(window_size), np.arange(window_size))
    distance = np.sqrt((x - window_size // 2)**2 + (y - window_size // 2)**2)
    weight = 1.0 / (1.0 + distance)  # Weighted distance

    # Normalize the weights
    weight /= weight.sum()

    # Apply convolution with the weighted kernel
    smoothed_data = convolve(np.nan_to_num(data), weight, mode='constant', cval=0.0)
    return smoothed_data

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

            # Multiply all pixel values by 100 to scale them
            data *= 100

            # Print initial counts of scaled pixel values
            print(f"Initial count of pixels with value 0: {np.sum(data == 0)}")
            print(f"Initial count of pixels with value 100: {np.sum(data == 100)}")

            # Apply weighted smoothing
            smoothed_data = weighted_smoothing(data, window_size=21)

            # Define tolerance to count scaled fractional values close to 0 or 100
            tolerance = 1e-2

            # Count pixels in different value ranges after smoothing
            count_zero = np.sum(np.abs(smoothed_data) < tolerance)
            count_hundred = np.sum(np.abs(smoothed_data - 100) < tolerance)
            count_fractional = np.sum((smoothed_data > tolerance) & (smoothed_data < 100 - tolerance))

            # Print new counts after smoothing
            print(f"Smoothed data count of pixels close to 0: {count_zero}")
            print(f"Smoothed data count of pixels close to 100: {count_hundred}")
            print(f"Smoothed data count of fractional values: {count_fractional}")

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
    output_file = "D:/temp/NewDatasetsStijn/CropGrids/RiceCropLand2020_resampled_Smoothened.tif"


    main(input_file, output_file)
