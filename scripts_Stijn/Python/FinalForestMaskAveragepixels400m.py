import rasterio
from rasterio.enums import Resampling
from rasterio.warp import calculate_default_transform
from rasterio.warp import calculate_default_transform, reproject
import numpy as np
import os
import glob

def adjust_forest_layers(loss_file, forestmask_file, output_dir, tile_info, target_pixel_size):
    print(f"Processing loss file: {loss_file}")
    
    with rasterio.open(loss_file) as src_loss:
        loss = src_loss.read(1, masked=True)
    
    print("Classifying forest loss...")
    loss_mask = np.where(((loss >=1) & (loss <= 19)), 1, 0)
    print(f"Unique values in loss_mask: {np.unique(loss_mask, return_counts=True)}")
    
    # Save the classified loss mask for inspection
    loss_classified_path = os.path.join(output_dir, f"{tile_info}_loss_classified.tif")
    loss_meta = src_loss.meta.copy()
    loss_meta.update(dtype='uint8')
    
    
    print("Loading forest mask...")
    with rasterio.open(forestmask_file) as src_forestmask:
        forestmask = src_forestmask.read(1, masked=True)
        forest_meta = src_forestmask.meta.copy()

    print("Applying loss classification to forest mask...")
    modified_forestmask = np.where(loss_mask == 1, 0, forestmask)
    modified_forestmask = np.where(np.isnan(modified_forestmask), 0, modified_forestmask)
    modified_forestmask = np.multiply(modified_forestmask, 100, dtype='uint16')
    
    # Set target resolution
    target_transform, target_width, target_height = calculate_default_transform(
        src_forestmask.crs, src_forestmask.crs, src_forestmask.width, src_forestmask.height,
        *src_forestmask.bounds, dst_width=int(src_forestmask.width * src_forestmask.res[0] / target_pixel_size[0]),
        dst_height=int(src_forestmask.height * src_forestmask.res[1] / abs(target_pixel_size[1]))
    )
    forest_meta.update({
    'dtype': 'uint16',
    'compress': 'LZW',
    'transform': target_transform,
    'width': target_width,
    'height': target_height
    })

    forestmask_2023_path = os.path.join(output_dir, f"{tile_info}_forestmask_2020_400m.tif")
    with rasterio.open(forestmask_2023_path, 'w', **forest_meta) as dst:
        reproject(
    source=modified_forestmask,
    destination=rasterio.band(dst, 1),
    src_transform=src_forestmask.transform,
    src_crs=src_forestmask.crs,
    dst_transform=target_transform,
    dst_crs=src_forestmask.crs,
    resampling=Resampling.average  # Change from nearest to average
)


    print("Save completed for forest mask.")

# File paths and processing logic
loss_dir = r"C:/Users/admin/Documents/Newdatasets/download Forestloss2023"
forestmask_dir = r"C:/Users/admin/Documents/Newdatasets/forestmasks_tiled"
output_dir = r"D:/temp/ForestmaskJonasscript/2020/400x400"  # Updated output directory

# Define the target pixel size as a tuple
target_pixel_size = (0.004000000000000000083, -0.004000000000000000083)  # Positive or negative for Y based on your raster orientation

if not os.path.exists(output_dir):
    os.makedirs(output_dir)
    print("Output directory created.")

loss_files = sorted(glob.glob(f"{loss_dir}/*.tif"))  # Sort files to maintain consistent order
start_index = 0  # Start from the beginning of the file list
end_index = 252  # End at the 252nd file

for loss_file in loss_files[start_index:end_index]:
    file_name = os.path.basename(loss_file)
    tile_info = file_name.replace("Hansen_GFC-2023-v1.11_lossyear_", "").replace(".tif", "")
    forestmask_file = os.path.join(forestmask_dir, f"{tile_info}.tif")
    
    if os.path.exists(forestmask_file):
        adjust_forest_layers(loss_file, forestmask_file, output_dir, tile_info, target_pixel_size)
    else:
        print(f"Missing forest mask file: {forestmask_file}")