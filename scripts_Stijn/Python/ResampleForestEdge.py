import os
import rasterio
from rasterio.enums import Resampling
from rasterio.warp import reproject, calculate_default_transform

def resample_raster_to_specific_resolution(input_path, output_path, new_resolution=(0.004, 0.004)):
    with rasterio.open(input_path) as src:
        affine, width, height = calculate_default_transform(
            src.crs, src.crs, src.width, src.height, *src.bounds, resolution=new_resolution
        )
        metadata = src.meta.copy()
        metadata.update({
            'transform': affine,
            'width': width,
            'height': height,
            'compress': 'lzw'  # Ensure compression to reduce file size
        })

        data = src.read(
            out_shape=(src.count, height, width),
            resampling=Resampling.nearest  # Use nearest neighbor resampling
        )

        with rasterio.open(output_path, 'w', **metadata) as dst:
            dst.write(data)
        print(f"Resampled {input_path} and saved to {output_path}")

# Directory setup
src_directory = r"D:\temp\NewDatasetsStijn\Forest edge\EdgeMaps"
output_directory = r"D:\temp\NewDatasetsStijn\Forest edge\ForestEdgeResampled"

os.makedirs(output_directory, exist_ok=True)

# Process each file
for filename in os.listdir(src_directory):
    if filename.endswith('_edge.tif'):  # Target files that end with '_edge.tif'
        src_path = os.path.join(src_directory, filename)
        base_name = os.path.splitext(filename)[0]
        output_path = os.path.join(output_directory, f"{base_name}_resampled.tif")
        resample_raster_to_specific_resolution(src_path, output_path)
        print(f"Processed {src_path} and saved to {output_path}")
