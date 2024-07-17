import os
import numpy as np
import rasterio
from scipy.ndimage import distance_transform_edt, binary_erosion, generate_binary_structure

def create_binary_forest_map(src_path, output_path, threshold=3000):
    print(f"Creating binary forest map for {src_path}")
    with rasterio.open(src_path) as src:
        data = src.read(1)
        meta = src.meta.copy()
        binary_map = (data >= threshold).astype(rasterio.uint8)
        meta.update(dtype=rasterio.uint8, compress='lzw')  # Add LZW compression
        
        with rasterio.open(output_path, 'w', **meta) as dst:
            dst.write(binary_map, 1)
    print(f"Binary map saved to {output_path}")

def calculate_distance_to_edge(src_path, output_path):
    print(f"Calculating distance to forest edge for {src_path}")
    with rasterio.open(src_path) as src:
        data = src.read(1)
        meta = src.meta.copy()
        meta.update(dtype='float32', compress='lzw')  # Add LZW compression
        distance_map = distance_transform_edt(data == 0)
        
        with rasterio.open(output_path, 'w', **meta) as dst:
            dst.write(distance_map.astype('float32'), 1)
    print(f"Distance map saved to {output_path}")

def calculate_edge_density(src_path, output_path, scale_factor):
    print(f"Calculating edge density for {src_path}")
    with rasterio.open(src_path) as src:
        data = src.read(1)
        meta = src.meta.copy()
        
        # Erosion to find edges
        struct = generate_binary_structure(2, 1)
        edges = binary_erosion(data, structure=struct) != data
        edge_density = edges.astype(float)
        
        # Resample edge density to a coarser resolution
        transform, width, height = rasterio.warp.calculate_default_transform(
            src.crs, src.crs, src.width // scale_factor, src.height // scale_factor,
            *src.bounds)
        meta.update({
            'dtype': 'float32',
            'compress': 'lzw',  # Ensure LZW compression
            'transform': transform,
            'width': width,
            'height': height
        })

        with rasterio.open(output_path, 'w', **meta) as dst:
            dst.write(edge_density, 1)
    print(f"Edge density map saved to {output_path}")

# Set directories
forestmask_dir = r"D:\temp\ForestmaskJonasscript\2024_1"
binary_dir = r"D:\temp\NewDatasetsStijn\Forest edge"
distance_dir = r"D:\temp\NewDatasetsStijn\Forest edge\DistanceToForestEdge"
density_dir = r"D:\temp\NewDatasetsStijn\Forest edge\ForestEdgeDensity"

# Ensure output directories exist
os.makedirs(binary_dir, exist_ok=True)
os.makedirs(distance_dir, exist_ok=True)
os.makedirs(density_dir, exist_ok=True)

# Process each file
for filename in os.listdir(forestmask_dir):
    if filename.endswith('.tif'):
        src_path = os.path.join(forestmask_dir, filename)
        base_name = os.path.splitext(filename)[0]

        # Paths for outputs
        binary_path = os.path.join(binary_dir, f"{base_name}_binary.tif")
        distance_path = os.path.join(distance_dir, f"{base_name}_distance.tif")
        density_path = os.path.join(density_dir, f"{base_name}_density.tif")

        # Create binary forest/non-forest map
        create_binary_forest_map(src_path, binary_path)

        # Calculate distance to forest edge
        calculate_distance_to_edge(binary_path, distance_path)

        # Calculate forest edge density
        calculate_edge_density(binary_path, density_path, scale_factor=10)

print("Processing completed for all tiles.")
