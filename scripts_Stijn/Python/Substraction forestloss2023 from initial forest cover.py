import rasterio
import numpy as np
import os

def adjust_forest_layers_based_on_loss(initial_forest_path, loss_year_path, output_path):
    with rasterio.open(initial_forest_path) as initial_forest:
        initial_forest_data = initial_forest.read(1)  # Read the first band

        with rasterio.open(loss_year_path) as loss_year:
            loss_year_data = loss_year.read(1)  # Read the first band
            
            # Set all pixels in initial forest data to 0 where loss year data > 0
            initial_forest_data[loss_year_data > 0] = 0

            with rasterio.open(
                output_path,
                'w',
                driver='GTiff',
                height=initial_forest.height,
                width=initial_forest.width,
                count=1,
                dtype=rasterio.uint16,  # Assuming initial forest data is uint16, change if different
                crs=initial_forest.crs,
                transform=initial_forest.transform
            ) as dst:
                dst.write(initial_forest_data, 1)  # Write the updated forest data

def extract_tile_info(filename):
    if len(filename) > 39:
        tile_info = filename[31:39]
    else:
        tile_info = "Unknown"
    return tile_info

def construct_path(tile_info, base_directory, suffix):
    filename = f"{tile_info}_2021-01-01_{suffix}.tif"
    return os.path.join(base_directory, tile_info, filename)

# Directory setups
initial_forest_directory = "D:/ff-dev/results/preprocessed/input/"
loss_year_directory = "C:/Users/admin/Documents/Newdatasets/Forest Mask 2023/Resampled and same extend2/"
output_directory = "C:/Users/admin/Documents/Newdatasets/Forest Mask 2023/ForestMask2023/"

if not os.path.exists(output_directory):
    os.makedirs(output_directory)

# Processing loop
for filename in os.listdir(loss_year_directory):
    if filename.endswith('.tif'):
        tile_info = extract_tile_info(filename)
        if tile_info != "Unknown":
            initial_forest_path = construct_path(tile_info, initial_forest_directory, "initialforestcover")
            loss_year_path = os.path.join(loss_year_directory, filename)
            output_filename = filename.replace('.tif', '_ForestMask2023.tif')
            output_path = os.path.join(output_directory, output_filename)
            
            if os.path.exists(initial_forest_path) and os.path.exists(loss_year_path):
                adjust_forest_layers_based_on_loss(initial_forest_path, loss_year_path, output_path)
                print(f"Processed and saved: {output_path}")
            else:
                print(f"Required files not found for: {tile_info}")
        else:
            print(f"Unknown tile information for file: {filename}")
