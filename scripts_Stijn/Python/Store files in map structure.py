import os
import shutil

# Define the source and target directories
source_dir = "D:/ff-dev/Stijn"
target_dir = "D:/ff-dev/results/preprocessed/input"

def move_files(source_dir, target_dir):
    # Walk through all files and subdirectories in the source directory
    for root, _, files in os.walk(source_dir):
        for file_name in files:
            if file_name.endswith(".tif"):
                # Extract the tile name from the file name (part before the first underscore)
                tile_name = file_name.split('_')[0] + "_" + file_name.split('_')[1]
                
                # Define the target directory for this tile
                tile_dir = os.path.join(target_dir, tile_name)
                
                # Ensure the target directory exists
                if os.path.exists(tile_dir):
                    # Define the source file path
                    source_file_path = os.path.join(root, file_name)
                    
                    # Define the target file path
                    target_file_path = os.path.join(tile_dir, file_name)
                    
                    # Move the file to the target directory
                    shutil.move(source_file_path, target_file_path)
                    
                    # Print a message indicating the file has been moved
                    print(f"Moved file: {file_name} to {tile_dir}")
                else:
                    print(f"Directory does not exist: {tile_dir}")

# Run the function to move the files
move_files(source_dir, target_dir)
