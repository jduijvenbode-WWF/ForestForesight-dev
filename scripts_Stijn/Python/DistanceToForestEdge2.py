import os
import numpy as np
import rasterio
from queue import Queue

def radial_distance_search(data, start_point):
    print(f"Starting radial search from center at {start_point}")
    queue = Queue()
    queue.put((start_point[0], start_point[1], 0))  # (x, y, distance)
    visited = set(start_point)
    directions = [(1, 0), (-1, 0), (0, 1), (0, -1)]  # 4-connectivity

    while not queue.empty():
        x, y, dist = queue.get()
        for dx, dy in directions:
            nx, ny = x + dx, y + dy
            if 0 <= nx < data.shape[0] and 0 <= ny < data.shape[1] and (nx, ny) not in visited:
                visited.add((nx, ny))
                if data[nx, ny] == 0:  # Edge found
                    print(f"Edge found at {nx, ny} with distance {dist + 1}")
                    return dist + 1
                queue.put((nx, ny, dist + 1))
    print(f"No edge found from center at {start_point}")
    return np.inf  # If no edge is found

def calculate_and_resample_distance(src_path, output_path, target_resolution=(0.004, 0.004)):
    print(f"Processing {src_path}")
    with rasterio.open(src_path) as src:
        data = src.read(1)
        
        # Handling no-data values and NaNs
        nodata = src.nodata
        if nodata is not None:
            data[data == nodata] = 0
        data[np.isnan(data)] = 0
        
        # Creating binary mask where non-forest is 0 (background)
        mask = data > 0
        print("Binary mask created, calculating distances...")

        # Set up metadata for output
        meta = src.meta.copy()
        meta.update({
            'dtype': 'float32',
            'compress': 'lzw',
            'count': 1,
        })

        # Prepare distance map
        distance_map = np.full(data.shape, np.inf, dtype=np.float32)

        # Assume grid cells are 400x400m, define centers accordingly
        step_x, step_y = int(400 / src.res[0]), int(400 / src.res[1])
        centers = [(x, y) for x in range(step_x//2, data.shape[0], step_x)
                          for y in range(step_y//2, data.shape[1], step_y)]

        # Calculate distance from each center
        for center in centers:
            distance_map[center] = radial_distance_search(mask, center)

        print(f"Distances calculated, saving to {output_path}")
        with rasterio.open(output_path, 'w', **meta) as dst:
            dst.write(distance_map, 1)
        print(f"Saved resampled distance map to {output_path}")

# Example paths setup
src_directory = "D:/temp/NewDatasetsStijn/Forest edge/EdgeMaps2"
output_directory = "D:/temp/NewDatasetsStijn/Forest edge/DistanceToForestEdge2"

os.makedirs(output_directory, exist_ok=True)

# Process each edge map file
for filename in os.listdir(src_directory):
    if filename.endswith('_edge2.tif'):
        src_path = os.path.join(src_directory, filename)
        base_name = os.path.splitext(filename)[0]
        output_path = os.path.join(output_directory, f"{base_name}_distance.tif")
        calculate_and_resample_distance(src_path, output_path)
