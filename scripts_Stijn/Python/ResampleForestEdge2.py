import os
import rasterio
from rasterio.enums import Resampling
from rasterio.warp import calculate_default_transform, reproject

def resample_raster_to_specific_resolution(input_path, output_path, new_resolution=(0.0004, 0.0004)):
    with rasterio.open(input_path) as src:
        transform, width, height = calculate_default_transform(
            src.crs, src.crs, src.width, src.height, *src.bounds, resolution=new_resolution
        )
        metadata = src.meta.copy()
        metadata.update({
            'transform': transform,
            'width': width,
            'height': height,
            'compress': 'lzw',  # Ensure compression to reduce file size
            'crs': src.crs
        })

        data = src.read(
            out_shape=(src.count, height, width),
            resampling=Resampling.nearest  # Use nearest neighbor resampling
        )

        with rasterio.open(output_path, 'w', **metadata) as dst:
            dst.write(data)

def process_directory(input_directory, output_directory, new_resolution=(0.0004, 0.0004)):
    os.makedirs(output_directory, exist_ok=True)
    
    for filename in os.listdir(input_directory):
        if filename.endswith('.tif'):
            input_path = os.path.join(input_directory, filename)
            base_name, ext = os.path.splitext(filename)
            output_path = os.path.join(output_directory, f"{base_name}_resampled{ext}")
            print(f"Processing {input_path} -> {output_path}")
            resample_raster_to_specific_resolution(input_path, output_path, new_resolution)

# Example usage
input_directory = "D:/temp/NewDatasetsStijn/Forest edge/DistanceToForestEdge2"
output_directory = "D:/temp/NewDatasetsStijn/Forest edge/DistanceToForestEdge2Resampled"
process_directory(input_directory, output_directory)
