import os

# Define the directory containing the files
directory = "D:/temp/NewDatasetsStijn/Forest edge/DistancetoForestEdge2024Processed"

# Define the part of the filename to be replaced and the new part
old_part = "forestmask_2024_binary_edge_resampled_distance_resampled_resampled_processed"
new_part = "2024-01-01-closenesstoforestedge"

# Iterate over all files in the directory
for filename in os.listdir(directory):
    # Check if the filename contains the old part
    if old_part in filename:
        # Create the new filename
        new_filename = filename.replace(old_part, new_part)
        # Construct full file paths
        old_filepath = os.path.join(directory, filename)
        new_filepath = os.path.join(directory, new_filename)
        # Rename the file
        os.rename(old_filepath, new_filepath)
        print(f'Renamed: {filename} to {new_filename}')

print("Renaming completed.")
