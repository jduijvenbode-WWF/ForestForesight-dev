import rasterio
import numpy as np

def merge_rasters(raster1_path, raster2_path, output_path):
    with rasterio.open(raster1_path) as src1, rasterio.open(raster2_path) as src2:
        # Calculate the intersection of both rasters
        intersection_left = max(src1.bounds.left, src2.bounds.left)
        intersection_bottom = max(src1.bounds.bottom, src2.bounds.bottom)
        intersection_right = min(src1.bounds.right, src2.bounds.right)
        intersection_top = min(src1.bounds.top, src2.bounds.top)

        # Check if there is an overlapping area
        if intersection_right > intersection_left and intersection_top > intersection_bottom:
            # Define the intersection bounding box (corrected variable usage)
            intersection = rasterio.coords.BoundingBox(
                left=intersection_left,
                bottom=intersection_bottom,
                right=intersection_right,
                top=intersection_top
            )

            # Read the data from both rasters within the intersection
            window1 = rasterio.windows.from_bounds(
                intersection.left, intersection.bottom, intersection.right, intersection.top, transform=src1.transform
            )
            window2 = rasterio.windows.from_bounds(
                intersection.left, intersection.bottom, intersection.right, intersection.top, transform=src2.transform
            )

            data1 = src1.read(1, window=window1)
            data2 = src2.read(1, window=window2)

            # Save the clipped extent of raster 1 as the first product
            clipped_raster1_path = output_path.replace('.tif', '_clipped_raster1.tif')
            new_profile = src1.profile.copy()
            new_profile.update({
                'height': window1.height,
                'width': window1.width,
                'transform': rasterio.windows.transform(window1, src1.transform),
                'compress': 'lzw'
            })
            with rasterio.open(clipped_raster1_path, 'w', **new_profile) as dst:
                dst.write(data1, 1)

            # Handling nodata values, setting them to 0
            nodata1 = src1.nodatavals[0]
            data1_nodata_zero = np.where(data1 == nodata1, 0, data1)

            # Save this raster where nodata is set to 0
            nodata_zero_path = output_path.replace('.tif', '_nodata_zero.tif')
            with rasterio.open(nodata_zero_path, 'w', **new_profile) as dst:
                dst.write(data1_nodata_zero, 1)

            # Choose data from Raster 1, fallback to Raster 2 if Raster 1 has nodata
            result_data = np.where(data1 == nodata1, data2, data1)

            # Save the final merged product
            with rasterio.open(output_path, 'w', **new_profile) as dst:
                dst.write(result_data, 1)
        else:
            print("No overlapping area found between the two rasters.")

# Example usage
merge_rasters(
    "D:/temp/NewDatasetsStijn/DevelopmentIndex/DevelopmentIndex/lulc-development-potential-indices_coal_dpi_classes_geographic.tif",
    "D:/temp/NewDatasetsStijn/ResearchARea_Polygon.tif",
    "D:/temp/NewDatasetsStijn/DevelopmentIndex/Clipped2/lulc-development-potential-indices_coal_dpi_classes_geographic_clipped2.tif"
)
