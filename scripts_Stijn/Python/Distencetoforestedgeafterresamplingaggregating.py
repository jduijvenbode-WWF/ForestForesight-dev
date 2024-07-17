import os
import numpy as np
import rasterio
from rasterio.enums import Resampling
from rasterio.warp import calculate_default_transform, reproject

def sum_high_res_values(src_path, output_path, high_res=(0.0004, 0.0004), final_res=(0.004, 0.004)):
    print(f"Processing {src_path}")
    with rasterio.open(src_path) as src:
        meta = src.meta.copy()
        src_bounds = src.bounds
        src_transform = src.transform

        # Calculate the new transformation and dimensions for high resolution
        high_transform, high_width, high_height = calculate_default_transform(
            src.crs, src.crs, src.width, src.height, *src_bounds,
            resolution=high_res
        )
        
        # Create an empty array for high resolution
        high_res_data = np.zeros((high_height, high_width), dtype=src.meta['dtype'])
        
        # Reproject to high resolution using nearest neighbor
        reproject(
            source=rasterio.band(src, 1),
            destination=high_res_data,
            src_transform=src_transform,
            src_crs=src.crs,
            dst_transform=high_transform,
            dst_crs=src.crs,
            resampling=Resampling.nearest
        )

        # Calculate the transformation and dimensions for final resolution
        final_transform, final_width, final_height = calculate_default_transform(
            src.crs, src.crs, high_width, high_height, *src_bounds,
            resolution=final_res
        )

        # Create an empty array for final resolution
        final_data = np.zeros((final_height, final_width), dtype=np.float32)  # Use float32 for sums

        # Aggregate high resolution data into final resolution
        step_y = int(final_res[1] / high_res[1])
        step_x = int(final_res[0] / high_res[0])
        
        for i in range(final_height):
            for j in range(final_width):
                vertical_slice = slice(i * step_y, min((i + 1) * step_y, high_height))
                horizontal_slice = slice(j * step_x, min((j + 1) * step_x, high_width))
                final_data[i, j] = np.sum(high_res_data[vertical_slice, horizontal_slice])

        # Remove the outermost right column of pixels
        final_data = final_data[:, :-1]
        final_width -= 1

        # Ensure the final bounds match the expected bounds
        final_bounds = (src_bounds.left, src_bounds.bottom, src_bounds.left + final_width * final_res[0], src_bounds.bottom + final_height * final_res[1])

        # Update metadata for the output file
        meta.update({
            'dtype': 'float32',
            'compress': 'lzw',
            'transform': final_transform,
            'width': final_width,
            'height': final_height,
            'crs': src.crs,
            'bounds': final_bounds
        })

        # Write output
        with rasterio.open(output_path, 'w', **meta) as dst:
            dst.write(final_data, 1)

        print(f"Saved to {output_path}")

# Directories
input_dir = "D:/temp/NewDatasetsStijn/Forest edge/DistanceToForestEdge2Resampled"
output_dir = "D:/temp/NewDatasetsStijn/Forest edge/DistanceToForestEdge2ResampledAggregated"
os.makedirs(output_dir, exist_ok=True)

for filename in os.listdir(input_dir):
    if filename.endswith('.tif'):  # Adjust the condition as needed
        src_path = os.path.join(input_dir, filename)
        output_path = os.path.join(output_dir, filename.replace('.tif', '_resampled.tif'))
        sum_high_res_values(src_path, output_path)
