import os
import rasterio
from scipy.ndimage import binary_erosion, convolve
import numpy as np

def create_edge_map(src_path, output_path):
    print(f"Creating edge map for {src_path}")
    with rasterio.open(src_path) as src:
        data = src.read(1)
        meta = src.meta.copy()

        # Define structuring element for 4-connectivity (orthogonal neighbors only)
        struct = [[0, 1, 0],
                  [1, 0, 1],
                  [0, 1, 0]]

        # Apply binary erosion to identify potential edges
        eroded_forest = binary_erosion(data, structure=struct)
        potential_edges = data & (~eroded_forest)

        # Use convolution to count non-forest neighbors for each potential edge pixel
        kernel = [[0, 1, 0],
                  [1, 0, 1],
                  [0, 1, 0]]
        non_forest_neighbors = convolve(potential_edges, kernel, mode='constant', cval=0)

        # Define forest edge pixels as having at least two non-forest neighbors
        edges = (non_forest_neighbors >= 2) & potential_edges

        # Mask out the borders to avoid false edges at the raster edges
        edges[0, :] = 0  # Top row
        edges[-1, :] = 0  # Bottom row
        edges[:, 0] = 0  # Left column
        edges[:, -1] = 0  # Right column

        # Convert edges to binary format and save
        edges = edges.astype(rasterio.uint8)
        meta.update(dtype=rasterio.uint8, compress='lzw')
        
        with rasterio.open(output_path, 'w', **meta) as dst:
            dst.write(edges, 1)
    print(f"Edge map saved to {output_path}")

binary_dir = r"D:\temp\NewDatasetsStijn\Forest edge\EdgeMaps3"
edge_dir = r"D:\temp\NewDatasetsStijn\Forest edge\EdgeMaps3\oud"
os.makedirs(edge_dir, exist_ok=True)

for filename in os.listdir(binary_dir):
    if filename.endswith('_binary.tif'):
        src_path = os.path.join(binary_dir, filename)
        base_name = os.path.splitext(filename)[0]
        output_path = os.path.join(edge_dir, f"{base_name}_edge2.tif")
        create_edge_map(src_path, output_path)
