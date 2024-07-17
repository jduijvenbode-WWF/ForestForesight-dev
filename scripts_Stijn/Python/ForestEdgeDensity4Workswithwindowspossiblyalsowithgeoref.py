import os
import rasterio
import numpy as np
from rasterio.enums import Resampling
from rasterio.warp import calculate_default_transform, reproject

def calculate_edge_density(src_path, output_path, target_resolution=(0.04, 0.04)):
    print(f"Calculating edge density for {src_path}")
    with rasterio.open(src_path) as src:
        meta = src.meta.copy()

        # Calculate the new transformation and dimensions based on the target resolution
        transform, width, height = calculate_default_transform(
            src.crs, src.crs, src.width, src.height, *src.bounds,
            resolution=target_resolution
        )
        
        # Update metadata for output
        meta.update({
            'dtype': 'uint32',  # Using uint32 to store sum of counts
            'compress': 'lzw',
            'transform': transform,
            'width': width,
            'height': height,
            'crs': src.crs
        })

        # Prepare output file early to use windowed writing
        with rasterio.open(output_path, 'w', **meta) as dst:
            # Create an empty array for the target resolution
            resampled_edges = np.zeros((height, width), dtype=np.uint32)

                    
            reproject(
    source=rasterio.band(src, 1),
    destination=resampled_edges,
    src_transform=src.transform,
    src_crs=src.crs,
    dst_transform=transform,
    dst_crs=src.crs,
    resampling=Resampling.max  # Maximum resampling to capture highest edge count
)

            
            # Write to file
            dst.write(resampled_edges, 1)
    print(f"Edge density map saved to {output_path}")

# Directory setup
edge_dir = r"D:\temp\NewDatasetsStijn\Forest edge\EdgeMaps2"
density_dir = r"D:\temp\NewDatasetsStijn\Forest edge\ForestEdgeDensity2"
os.makedirs(density_dir, exist_ok=True)

for filename in os.listdir(edge_dir):
    if filename.endswith('_edge.tif'):
        src_path = os.path.join(edge_dir, filename)
        base_name = os.path.splitext(filename)[0]
        output_path = os.path.join(density_dir, f"{base_name}_density2.tif")
        calculate_edge_density(src_path, output_path)

