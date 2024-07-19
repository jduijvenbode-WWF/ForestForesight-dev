import os
import rasterio
import numpy as np
import csv
from rasterio.warp import reproject, Resampling

def get_monthly_alert_counts(alert_files, tree_cover_path, thresholds):
    """Calculate the number of alerts for each threshold of tree coverage."""
    with rasterio.open(tree_cover_path) as tree_cover_src:
        tree_cover_data = tree_cover_src.read(1)  # Read the tree cover data
        tree_cover_transform = tree_cover_src.transform  # Transformation of tree cover

    results = {threshold: [] for threshold in thresholds}
    for alert_file in alert_files:
        with rasterio.open(alert_file) as src:
            alert_data = src.read(1)
            # Create an array to hold the resampled alert data
            resampled_alert_data = np.zeros(tree_cover_data.shape, dtype=src.dtypes[0])
            # Reproject alert data to match tree cover data
            reproject(
                source=alert_data,
                destination=resampled_alert_data,
                src_transform=src.transform,
                src_crs=src.crs,
                dst_transform=tree_cover_transform,
                dst_crs=tree_cover_src.crs,
                resampling=Resampling.nearest  # Use nearest neighbor for alerts to avoid fractional values
            )

        # Process data for each threshold
        for threshold in thresholds:
            valid_tree_cover = tree_cover_data >= threshold
            alert_active = resampled_alert_data > 0
            results[threshold].append(np.sum(np.logical_and(valid_tree_cover, alert_active)))

    return results

def save_results_to_csv(results, tile_name, output_file):
    """Save the coverage results to a CSV file."""
    with open(output_file, 'a', newline='') as csvfile:
        writer = csv.writer(csvfile)
        for threshold, counts in results.items():
            writer.writerow([tile_name, threshold, *counts])

def analyze_coverage(base_alert_directory, base_tree_cover_directory, output_csv, thresholds):
    """Process each tile and compute the coverage analysis."""
    with open(output_csv, 'w', newline='') as f:
        writer = csv.writer(f)
        writer.writerow(['Tile', 'Threshold', *['Month'+str(i+1) for i in range(len(next(os.walk(base_alert_directory))[2]))]])


    for tile_folder in os.listdir(base_alert_directory):
        alert_folder_path = os.path.join(base_alert_directory, tile_folder)
        alert_files = [os.path.join(alert_folder_path, f) for f in os.listdir(alert_folder_path) if f.endswith('.tif')]
        tree_cover_file = os.path.join(base_tree_cover_directory, f'treecover2010_{tile_folder}.tif')

        if not alert_files or not os.path.exists(tree_cover_file):
            print(f"Missing data for {tile_folder}")
            continue

        coverage_results = get_monthly_alert_counts(alert_files, tree_cover_file, thresholds)
        save_results_to_csv(coverage_results, tile_folder, output_csv)

if __name__ == "__main__":
    base_alert_directory = "D:/ff-dev/results/preprocessed/groundtruth"
    base_tree_cover_directory = "D:/temp/NewDatasetsStijn/ForestCover2010/ForestCover2010"
    output_csv = "D:/temp/NewDatasetsStijn/ForestCover2010/ForestCover2010Results/results.csv"
    thresholds = [0, 10, 20, 30, 40, 50]  # Tree coverage thresholds

    analyze_coverage(base_alert_directory, base_tree_cover_directory, output_csv, thresholds)
