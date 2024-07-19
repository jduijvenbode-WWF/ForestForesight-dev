import rasterio
import os

def clip_and_save_raster(raster1_path, raster2_path, output_path):
    with rasterio.open(raster1_path) as src1, rasterio.open(raster2_path) as src2:
        intersection_left = max(src1.bounds.left, src2.bounds.left)
        intersection_bottom = max(src1.bounds.bottom, src2.bounds.bottom)
        intersection_right = min(src1.bounds.right, src2.bounds.right)
        intersection_top = min(src1.bounds.top, src2.bounds.top)

        if intersection_right > intersection_left and intersection_top > intersection_bottom:
            # Define the intersection bounding box
            intersection = rasterio.coords.BoundingBox(
                left=intersection_left,
                bottom=intersection_bottom,
                right=intersection_right,
                top=intersection_top
            )

            # Read the data from raster 1 within the intersection
            window = rasterio.windows.from_bounds(
                intersection.left, intersection.bottom, intersection.right, intersection.top, transform=src1.transform
            )

            data = src1.read(1, window=window)

            new_profile = src1.profile.copy()
            new_profile.update({
                'height': window.height,
                'width': window.width,
                'transform': rasterio.windows.transform(window, src1.transform),
                'compress': 'lzw'  # LZW compression
            })

            with rasterio.open(output_path, 'w', **new_profile) as dst:
                dst.write(data, 1)
            print(f"Processed and saved: {output_path}")
        else:
            print("No overlapping area found.")

def process_directory(directory, reference_raster_path, output_dir):
    for filename in os.listdir(directory):
        if filename.endswith(".tif") and 'lulc-development-potential-indices' in filename:
            raster1_path = os.path.join(directory, filename)
            output_filename = filename.replace('.tif', '_clipped2.tif')
            output_path = os.path.join(output_dir, output_filename)
            clip_and_save_raster(raster1_path, reference_raster_path, output_path)

# Example usage
directory = "D:/temp/NewDatasetsStijn/Soy/2021"
reference_raster_path = "D:/temp/NewDatasetsStijn/ResearchARea_Polygon.tif"
output_dir = "D:/temp/NewDatasetsStijn/Soy/2021_processed"

process_directory(directory, reference_raster_path, output_dir)
