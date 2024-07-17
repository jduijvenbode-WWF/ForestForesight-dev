import os
import subprocess

def merge_tifs(input_directory, output_file, gdal_merge_path):
    # Find all .tif files in the directory
    print("Searching for .tif files in the directory...")
    tif_files = [os.path.join(input_directory, f) for f in os.listdir(input_directory) if f.endswith('.tif')]
    
    if not tif_files:
        print("No .tif files found in the directory.")
        return
    
    print(f"Found {len(tif_files)} .tif files to merge.")
    
    # Construct the command to run gdal_merge.py
    gdal_command = ['python', gdal_merge_path, '-o', output_file, '-of', 'GTiff'] + tif_files
    print("Constructed gdal_merge.py command:")
    print(' '.join(gdal_command))
    
    # Run the command
    try:
        subprocess.run(gdal_command, check=True)
        print(f"Successfully merged .tif files into {output_file}")
    except subprocess.CalledProcessError as e:
        print(f"Error occurred while merging .tif files: {e}")
    except FileNotFoundError as e:
        print(f"gdal_merge.py not found: {e}")
    except Exception as e:
        print(f"An unexpected error occurred: {e}")

# Directory containing .tif files
input_directory = r"D:\temp\NewDatasetsStijn\Forest edge\EdgeMaps2"
output_file = r"D:\temp\NewDatasetsStijn\Forest edge\EdgeMaps3\merged.tif"
gdal_merge_path = r"C:\Program Files\GDAL\gdal_merge.py"  # Full path to gdal_merge.py

# Merge the .tif files
merge_tifs(input_directory, output_file, gdal_merge_path)
