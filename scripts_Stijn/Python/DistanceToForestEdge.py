import os
import rasterio
import numpy as np
from scipy.ndimage import distance_transform_edt
from rasterio.enums import Resampling

def calculate_and_resample_distance(src_path, output_path, target_resolution=(0.004, 0.004)):
    print(f"Processing {src_path}")
    with rasterio.open(src_path) as src:
        data = src.read(1)
        
        # Handling no-data values and NaNs
        nodata = src.nodata
        if nodata is not None:
            data[data == nodata] = 0
        data[np.isnan(data)] = 0
        
        # Creating binary mask where non-forest is 0 (background)
        mask = data > 0
        
        # Calculating distance to the nearest non-forest
        distance_transform = distance_transform_edt(~mask)
        
        # Prepare to resample the distance map to coarser resolution
        transform, width, height = rasterio.warp.calculate_default_transform(
            src.crs, src.crs, src.width, src.height, *src.bounds,
            dst_width=int((src.bounds.right - src.bounds.left) / target_resolution[0]),
            dst_height=int((src.bounds.top - src.bounds.bottom) / target_resolution[1]))

        # Setting up metadata for output
        meta = src.meta.copy()
        meta.update({
            'dtype': 'float32',
            'compress': 'lzw',
            'transform': transform,
            'width': width,
            'height': height,
            'crs': src.crs
        })

        # Resampling the distance transform
        resampled_distance = np.zeros((height, width), dtype=np.float32)
        rasterio.warp.reproject(
            source=distance_transform,
            destination=resampled_distance,
            src_transform=src.transform,
            src_crs=src.crs,
            dst_transform=transform,
            dst_crs=src.crs,
            resampling=Resampling.average
        )

        # Save the resampled data
        with rasterio.open(output_path, 'w', **meta) as dst:
            dst.write(resampled_distance, 1)
        print(f"Saved resampled distance map to {output_path}")

# Directory setup
src_directory = r"D:\temp\NewDatasetsStijn\Forest edge\EdgeMaps2"
output_directory = r"D:\temp\NewDatasetsStijn\Forest edge\DistanceToForestEdge2"

os.makedirs(output_directory, exist_ok=True)

# Process each file
for filename in os.listdir(src_directory):
    if filename.endswith('_edge.tif'):
        src_path = os.path.join(src_directory, filename)
        base_name = os.path.splitext(filename)[0]
        output_path = os.path.join(output_directory, f"{base_name}_distance.tif")
        calculate_and_resample_distance(src_path, output_path)
