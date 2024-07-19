import os
import rasterio
from rasterio.enums import Resampling
from rasterio.warp import calculate_default_transform, reproject
import numpy as np

def resample_and_multiply(input_raster_path, reference_folder, output_folder):
    with rasterio.open(input_raster_path) as input_raster:
        input_data = input_raster.read(1)
        input_meta = input_raster.meta.copy()

        # Set nodata explicitly if not set
        if 'nodata' not in input_meta or input_meta['nodata'] is None:
            input_meta['nodata'] = -9999
            input_data[input_data == input_meta['nodata']] = -9999

        for subdir, dirs, files in os.walk(reference_folder):
            for file in files:
                if file.endswith("landpercentage.tif"):  # Specific reference files
                    reference_raster_path = os.path.join(subdir, file)
                    with rasterio.open(reference_raster_path) as ref_raster:
                        ref_data = ref_raster.read(1)

                        # Debug print
                        print(f"Unique values in reference data before modification: {np.unique(ref_data)}")

                        multiplier = np.where(ref_data == 254, 1, 0)

                        # Debug print
                        print(f"Multiplier unique values: {np.unique(multiplier)}")

                        resampled_data = np.empty(shape=(ref_raster.height, ref_raster.width), dtype=rasterio.float32)
                        reproject(
                            source=input_data,
                            destination=resampled_data,
                            src_transform=input_raster.transform,
                            src_crs=input_raster.crs,
                            dst_transform=ref_raster.transform,
                            dst_crs=ref_raster.crs,
                            resampling=Resampling.nearest
                        )

                        # Apply the multiplier
                        multiplied_data = resampled_data * multiplier

                        # Debug print
                        print(f"Unique values in multiplied data: {np.unique(multiplied_data)}")

                        output_meta = ref_raster.meta.copy()
                        output_meta.update({
                            'dtype': 'float32',
                            'height': ref_raster.height,
                            'width': ref_raster.width,
                            'transform': ref_raster.transform,
                            'compress': 'LZW',
                            'nodata': -9999
                        })

                        output_file_name = os.path.basename(subdir) + "_" + os.path.basename(input_raster_path)
                        output_raster_path = os.path.join(output_folder, output_file_name)
                        with rasterio.open(output_raster_path, 'w', **output_meta) as dst:
                            dst.write(multiplied_data, 1)
                            print(f"Processed and saved: {output_raster_path}")

# Directories setup
input_folder = "D:/temp/NewDatasetsStijn/Forest edge/DistanceToForestEdge2ResampledAggregated"
output_folder = "D:/temp/NewDatasetsStijn/Forest edge/DistancetoForestEdgeProcessed"
reference_folder = r"D:\ff-dev\results\preprocessed\input"

# Process each input file
files_to_process = os.listdir(input_folder)
for input_file in files_to_process:
    if input_file.endswith(".tif"):  # Make sure to process only TIFF files
        input_path = os.path.join(input_folder, input_file)
        resample_and_multiply(input_path, reference_folder, output_folder)
