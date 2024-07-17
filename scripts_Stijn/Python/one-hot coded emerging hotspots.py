import rasterio
import numpy as np

# Define the input and output file paths
input_path = "D:/temp/NewDatasetsStijn/HotSpot/gfw_emerging_hot_spots_v2.tif"
output_path = "D:/temp/NewDatasetsStijn/HotSpot/one_hot_encoded_dataset.tif"

# Define the categories and their values
categories = {
    "NoHotSpot": 0,
    "DiminishingHotSpot": 1,
    "IntensifyingHotSpot": 2,
    "NewHotSpot": 3,
    "PersistentHotSpot": 4,
    "SporadicHotSpot": 5
}

# Open the input raster and read its metadata
with rasterio.open(input_path) as src:
    # Read the first band into a numpy array
    raster_data = src.read(1)

    # Initialize an empty array with shape (number of categories, rows, cols)
    binary_stack = np.zeros((len(categories), raster_data.shape[0], raster_data.shape[1]), dtype=np.uint8)

    # Loop through each category and create a binary mask
    for i, (category_name, category_value) in enumerate(categories.items()):
        binary_stack[i] = (raster_data == category_value).astype(np.uint8)

    # Update metadata for the output raster
    output_meta = src.meta.copy()
    output_meta.update({
        "driver": "GTiff",
        "dtype": "uint8",
        "count": len(categories),
        "compress": "LZW"
    })

# Write the binary stack to an output file with LZW compression
with rasterio.open(output_path, "w", **output_meta) as dst:
    for i in range(len(categories)):
        dst.write(binary_stack[i], i + 1)

print(f"Export complete: {output_path}")
