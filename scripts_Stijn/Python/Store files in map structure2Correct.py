import os
import shutil

# Define the paths
featurespertile_path = r"D:\temp\NewDatasetsStijn\CropGrids\CropGridsResampledDistanceToprocessed" 
input_path = "D:/ff-dev/results/preprocessed/input"

def list_directories(path):
    # Get a list of all directories in the given path
    directories = [name for name in os.listdir(path) if os.path.isdir(os.path.join(path, name))]
    return directories

def move_files_by_code(source_dir, target_dir):
    # List directories in the target path
    target_dirs = list_directories(target_dir)
    
    for file_name in os.listdir(source_dir):
        if file_name.endswith(".tif"):
            # Extract the first 8 characters to get the code including the underscore
            code = file_name[:8]

            # Find the matching directory in the target path
            matching_dir = next((d for d in target_dirs if code in d), None)
            
            if matching_dir:
                # Define the source and target file paths
                source_file_path = os.path.join(source_dir, file_name)
                target_dir_path = os.path.join(target_dir, matching_dir)
                target_file_path = os.path.join(target_dir_path, file_name)
                
                # Move the file to the target directory
                shutil.move(source_file_path, target_file_path)
                
                # Print a message indicating the file has been moved
                print(f"Moved file: {file_name} from {source_file_path} to {target_file_path}")

# Run the function to move the files
move_files_by_code(featurespertile_path, input_path)
