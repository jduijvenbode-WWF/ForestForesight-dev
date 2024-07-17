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

# Example usage
input_file = "D:/temp/NewDatasetsStijn/Forest edge/EdgeMaps2"
output_file = "D:/temp/NewDatasetsStijn/Forest edge/EdgeMaps2resampled
resample_raster_to_specific_resolution(input_file, output_file)
