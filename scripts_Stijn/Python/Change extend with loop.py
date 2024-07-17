import rasterio
from rasterio.windows import Window
from rasterio.enums import Resampling
import os

def pad_raster(source_path, reference_path, output_path):
    print("Opening reference raster...")
    with rasterio.open(reference_path) as ref:
        print("Reference raster opened successfully.")
        ref_transform = ref.transform
        ref_width = ref.width
        ref_height = ref.height

        print("Opening source raster...")
        with rasterio.open(source_path) as src:
            print("Source raster opened successfully.")
            src_transform = src.transform
            src_data = src.read(1)  # Reading the first band

            # Calculate offsets
            offset_x = int((src_transform.xoff - ref_transform.xoff) / ref_transform[0])
            offset_y = int((src_transform.yoff - ref_transform.yoff) / ref_transform[4])
            print(f"Offsets calculated: {offset_x}, {offset_y}")

            print("Creating new raster...")
            with rasterio.open(
                output_path,
                'w',
                driver='GTiff',
                height=ref_height,
                width=ref_width,
                count=1,
                dtype=src_data.dtype,
                crs=src.crs,
                transform=ref_transform
            ) as new_data:
                print("New raster created. Writing data...")
                new_data.write(src_data, 1, window=Window(offset_x, offset_y, src.width, src.height))
                print("Data written successfully.")

                # Ensure data is saved and flushed
                new_data.close()
            print("New raster dataset closed.")

# Function to extract tile information from the filename
def extract_tile_info(filename):
    # Assuming the tile info starts at position 31 and spans 8 characters
    if len(filename) > 39:
        tile_info = filename[31:39]
    else:
        tile_info = "Unknown"
    return tile_info

# Function to construct the elevation file path
def construct_elevation_path(tile_info, base_elevation_directory):
    elevation_filename = f"{tile_info}_2021-01-01_initialforestcover.tif"
    elevation_path = os.path.join(base_elevation_directory, tile_info, elevation_filename)
    return elevation_path

# Directories setup
source_directory = "C:\Users\admin\Documents\Newdatasets\ForestmaskJonasscript"
base_elevation_directory = "D:/ff-dev/results/preprocessed/input/"
resampled_directory = "D:\temp\ForestmaskJonasscriptResampled400x400"

if not os.path.exists(resampled_directory):
    os.makedirs(resampled_directory)

# Processing loop
for filename in os.listdir(source_directory):
    if filename.endswith('.tif'):
        source_path = os.path.join(source_directory, filename)
        tile_info = extract_tile_info(filename)
        if tile_info != "Unknown":
            reference_path = construct_elevation_path(tile_info, base_elevation_directory)
            output_filename = filename.replace('.tif', '2.tif')
            output_path = os.path.join(resampled_directory, output_filename)
            if os.path.exists(reference_path):
                pad_raster(source_path, reference_path, output_path)
            else:
                print(f"Reference file not found for: {filename}")
        else:
            print(f"Unknown tile information for file: {filename}")



