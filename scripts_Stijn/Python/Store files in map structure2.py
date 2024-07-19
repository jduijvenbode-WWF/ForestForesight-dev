import os
import shutil

# Define the paths
featurespertile_path = "D:/ff-dev/results/preprocessed/featurespertile/Together"
input_path = "D:/ff-dev/results/preprocessed/input"

def list_directories(path):
    # Get a list of all directories in the given path
    directories = [name for name in os.listdir(path) if os.path.isdir(os.path.join(path, name))]
    return directories

def move_files(source_dir, target_dir):
    # List directories in the source and target paths
    source_dirs = set(list_directories(source_dir))
    target_dirs = set(list_directories(target_dir))
    
    # Find directories that are common to both source and target
    common_dirs = source_dirs.intersection(target_dirs)
    
    for dir_name in common_dirs:
        # Define the full paths for the source and target directories
        source_dir_path = os.path.join(source_dir, dir_name)
        target_dir_path = os.path.join(target_dir, dir_name)
        
        # List all files in the source directory
        files = os.listdir(source_dir_path)
        
        for file_name in files:
            # Define the source and target file paths
            source_file_path = os.path.join(source_dir_path, file_name)
            target_file_path = os.path.join(target_dir_path, file_name)
            
            # Move the file to the target directory
            shutil.move(source_file_path, target_file_path)
            
            # Print a message indicating the file has been moved
            print(f"Moved file: {file_name} from {source_dir_path} to {target_dir_path}")

# Run the function to move the files
move_files(featurespertile_path, input_path)
