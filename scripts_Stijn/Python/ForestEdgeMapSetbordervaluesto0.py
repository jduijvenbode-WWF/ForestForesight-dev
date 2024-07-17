import os
import rasterio
import numpy as np

def mask_outer_pixels(src_path, output_path):
    print(f"Processing file {src_path}")
    with rasterio.open(src_path) as src:
        data = src.read(1)
        meta = src.meta.copy()

        # Set the values of the outer pixels to 0
        data[0, :] = 0  # Top row
        data[-1, :] = 0  # Bottom row
        data[:, 0] = 0  # Left column
        data[:, -1] = 0  # Right column

        meta.update(dtype=rasterio.uint8, compress='lzw')
        
        with rasterio.open(output_path, 'w', **meta) as dst:
            dst.write(data, 1)
    print(f"Processed file saved to {output_path}")

# Directory setup
input_dir = r"D:\temp\NewDatasetsStijn\Forest edge\EdgeMaps"
output_dir = r"D:\temp\NewDatasetsStijn\Forest edge\EdgeMaps2"
os.makedirs(output_dir, exist_ok=True)

for filename in os.listdir(input_dir):
    if filename.endswith('.tif'):
        src_path = os.path.join(input_dir, filename)
        output_path = os.path.join(output_dir, filename)
        mask_outer_pixels(src_path, output_path)
