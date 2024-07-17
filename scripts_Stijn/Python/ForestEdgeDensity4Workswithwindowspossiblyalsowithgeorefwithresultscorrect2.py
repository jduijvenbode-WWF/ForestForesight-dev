
import os
import numpy as np
import rasterio
from rasterio.enums import Resampling
from rasterio.warp import calculate_default_transform, reproject

def count_high_res_edges(src_path, output_path, high_res=(0.0001, 0.0001), final_res=(0.004, 0.004)):
    print(f"Processing {src_path}")
    with rasterio.open(src_path) as src:
        meta = src.meta.copy()

        # Calculate the new transformation and dimensions for high resolution
        high_transform, high_width, high_height = calculate_default_transform(
            src.crs, src.crs, src.width, src.height, *src.bounds,
            resolution=high_res
        )
        
        # Create an empty array for high resolution
        high_res_data = np.zeros((high_height, high_width), dtype=src.meta['dtype'])
        
        # Reproject to high resolution using nearest neighbor
        reproject(
            source=rasterio.band(src, 1),
            destination=high_res_data,
            src_transform=src.transform,
            src_crs=src.crs,
            dst_transform=high_transform,
            dst_crs=src.crs,
            resampling=Resampling.nearest
        )

        # Calculate the transformation and dimensions for final resolution
        final_transform, final_width, final_height = calculate_default_transform(
            src.crs, src.crs, high_width, high_height, *src.bounds,
            resolution=final_res
        )

        # Create an empty array for final resolution
        final_data = np.zeros((final_height, final_width), dtype=np.uint32)  # Use uint32 for counts

        # Aggregate high resolution data into final resolution
        for i in range(final_height):
            for j in range(final_width):
                vertical_slice = slice(i * int(final_res[0] / high_res[0]), (i + 1) * int(final_res[0] / high_res[0]))
                horizontal_slice = slice(j * int(final_res[1] / high_res[1]), (j + 1) * int(final_res[1] / high_res[1]))
                final_data[i, j] = np.sum(high_res_data[vertical_slice, horizontal_slice])

        # Update metadata for the output file
        meta.update({
            'dtype': 'uint32',
            'compress': 'lzw',
            'transform': final_transform,
            'width': final_width,
            'height': final_height,
            'crs': src.crs
        })

        # Write output
        with rasterio.open(output_path, 'w', **meta) as dst:
            dst.write(final_data, 1)

        print(f"Saved to {output_path}")


# Directories
edge_dir = r"D:\temp\NewDatasetsStijn\Forest edge\EdgeMaps3"
density_dir = r"D:\temp\NewDatasetsStijn\Forest edge\ForestEdgeDensity3"
os.makedirs(density_dir, exist_ok=True)

for filename in os.listdir(edge_dir):
    if filename.endswith('_edge2.tif'):
        src_path = os.path.join(edge_dir, filename)
        output_path = os.path.join(density_dir, filename.replace('_edge2.tif', '_density3.tif'))
        count_high_res_edges(src_path, output_path)
