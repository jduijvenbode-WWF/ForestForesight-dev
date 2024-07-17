import os
import rasterio
import numpy as np

def create_binary_forest_map(src_path, output_path, threshold=1):
    print(f"Creating binary forest map for {src_path}")
    with rasterio.open(src_path) as src:
        data = src.read(1)
        meta = src.meta.copy()
        # Convert data to binary format based on threshold
        binary_map = (data >= threshold).astype(rasterio.uint8)
        meta.update(dtype=rasterio.uint8, compress='lzw')
        
        with rasterio.open(output_path, 'w', **meta) as dst:
            dst.write(binary_map, 1)
    print(f"Binary map saved to {output_path}")

# Directory setup
forestmask_dir = r"D:\temp\ForestmaskJonasscript\2024_1"
binary_dir = r"D:\temp\NewDatasetsStijn\Forest edge"

os.makedirs(binary_dir, exist_ok=True)

# Process each file
for filename in os.listdir(forestmask_dir):
    if filename.endswith('.tif'):
        src_path = os.path.join(forestmask_dir, filename)
        base_name = os.path.splitext(filename)[0]
        output_path = os.path.join(binary_dir, f"{base_name}_binary.tif")
        create_binary_forest_map(src_path, output_path)
