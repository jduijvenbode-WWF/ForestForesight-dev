import os
import sys
import numpy as np
import rasterio
from rasterio.enums import Resampling
from rasterio.warp import calculate_default_transform, reproject
from scipy.ndimage import convolve

def weighted_smoothing(data, window_size):
    # Create a weighted distance matrix
    x, y = np.meshgrid(np.arange(window_size), np.arange(window_size))
    distance = np.sqrt((x - window_size // 2)**2 + (y - window_size // 2)**2)
    weight = 1.0 / (1.0 + distance)  # Weighted distance
    weight /= weight.sum()  # Normalize the weights
    return convolve(np.nan_to_num(data), weight, mode='constant', cval=0.0)

def resample_and_multiply(input_raster_path, reference_raster_path, output_raster_path):
    with rasterio.open(input_raster_path) as input_raster:
        input_data = input_raster.read(1)
        input_meta = input_raster.meta.copy()

        with rasterio.open(reference_raster_path) as ref_raster:
            ref_transform, ref_width, ref_height = calculate_default_transform(
                input_raster.crs, ref_raster.crs, ref_raster.width, ref_raster.height, *ref_raster.bounds)
            ref_data = ref_raster.read(1)

            resampled_data = np.empty(shape=(ref_height, ref_width), dtype=rasterio.float32)
            reproject(
                source=input_data,
                destination=resampled_data,
                src_transform=input_raster.transform,
                src_crs=input_raster.crs,
                dst_transform=ref_transform,
                dst_crs=ref_raster.crs,
                resampling=Resampling.nearest
            )

            multiplied_data = resampled_data * ref_data
            output_meta = ref_raster.meta.copy()
            output_meta.update({
                'dtype': 'float32',
                'height': ref_height,
                'width': ref_width,
                'transform': ref_transform,
                'compress': 'LZW'
            })

            with rasterio.open(output_raster_path, 'w', **output_meta) as dst:
                dst.write(multiplied_data, 1)

def main(input_file, output_file):
    try:
        with rasterio.open(input_file) as src:
            data = src.read(1)  # Assume single-band raster
            nodata_value = src.nodata
            if nodata_value is not None:
                data[data == nodata_value] = 0

            smoothed_data = weighted_smoothing(data, 21)
            profile = src.profile
            transform = profile["transform"]
            crs = profile["crs"]            
            
            profile.update(dtype=rasterio.float32, count=1)

            with rasterio.open(output_file, 'w', **profile) as dst:
                dst.write(smoothed_data, 1)

        print(f"Smoothing operation completed successfully for {os.path.basename(output_file)}.")

    except Exception as e:
        print(f"An error occurred: {e}")
        sys.exit(1)



if __name__ == "__main__":
    input_folder = r"D:\temp\NewDatasetsStijn\Soy\2021"
    output_folder = r"D:\temp\NewDatasetsStijn\Soy\Soy2021_smoothed"
    reference_folder = r"D:\ff-dev\results\preprocessed\input"

    files_to_process = ["Cattle Distribution AW.tif", "Cattle Distribution DA.tif"]
    reference_files = ["00N_000E_2021-01-01_landpercentage.tif", "00N_010E_2021-01-01_landpercentage.tif"]

    for input_file, ref_file in zip(files_to_process, reference_files):
        input_path = os.path.join(input_folder, input_file)
        output_path = os.path.join(output_folder, input_file.replace(".tif", " Smoothed.tif"))
        reference_path = os.path.join(reference_folder, ref_file)

        if not os.path.isfile(output_path):
            main(input_path, output_path)
            resample_and_multiply(output_path, reference_path, output_path.replace(" Smoothed", " Final"))
            print(f"Processing completed for {input_file}")
        else:
            print(f"Output file already exists: {output_path}")
